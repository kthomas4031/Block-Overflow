pragma solidity 0.4.24;

import "./EIP20Interface.sol";


contract Forum {
    //Log tracking
    event _UpvoteCast(address upvoter, uint amount);
    event _DownvoteCast(address downvoter, uint amount);
    event _SubmissionUploaded(uint indexed listingIndex);
    event _SubmissionPassed(uint indexed listingIndex);
    event _SubmissionDenied(uint indexed listingIndex);
    event _SubmissionRemoved(uint indexed listingIndex);
    event _ResponseSubmitted(uint indexed listingIndex, uint indexed responseIndex);
    event _ResponsePublished(uint indexed listingIndex, uint indexed responseIndex);
    event _ResponseRemoved(uint indexed listingIndex, uint indexed responseIndex);
    event _ResponseDenied(uint indexed listingIndex, uint indexed responseIndex);
    event _FriendAdded(address user, address friend);
    event _FriendRemoved(address user, address friend);

    //Structures
    struct Submission {
        address submitter; //Include submitter and initial token stake as first TokenStake
        uint submittedDataIndex;
        uint expirationTime; 
        uint upvoteTotal;
        uint downvoteTotal;
        address[] promoters;
        address[] challengers;
        mapping(address => uint) balances;
        bool completed;
        Answer[26] answers;
    }

    struct Answer {
        address respondent;
        uint upvoteTotal;
        uint downvoteTotal;
        address[] promoters;
        address[] challengers;
        mapping(address => uint) balances;
        uint index;
    }

    struct User {
        string name;
        address[] friends;
        uint[] postIndices;
        uint contributionScore;
    }


    //Global variables
    uint public minDeposit;
    address private owner;
    EIP20Interface public token;
    Submission[] allSubmissions;
    mapping(address => User) userBase;


    //Constructor
    constructor (address _tokenAddress) public {
        owner = msg.sender;
        minDeposit = 50;
        token = EIP20Interface(_tokenAddress);
    }
    

    //Modifiers
    modifier submitterOnly (Submission memory sub) {
        require(msg.sender == sub.submitter || msg.sender == owner, "Invalid Credentials");
        _;
    }

    modifier responderOnly (Answer memory answer) {
        require(msg.sender == answer.respondent || msg.sender == owner, "Invalid Credentials");
        _;
    }
     
    modifier ownerOnly {
        require(msg.sender == owner, "You are not me, stop pretending.");
        _;
    }

    modifier timeTested (Submission memory sub) {
        require(sub.expirationTime < now, "Expiration Time Exceeded");
        _;
    }

    modifier incomplete (Submission memory sub) {
        require(sub.completed != true, "Submisison Completed");
        _;
    }


    //Functions
    function uploadSub (uint newSub, uint amount) public payable {
        require(amount >= minDeposit);
        token.transferFrom(msg.sender, address(this), amount);

        Submission memory addedSub;
        addedSub.submitter = msg.sender;
        addedSub.submittedDataIndex = newSub;
        addedSub.expirationTime = now + 604800;
        addedSub.downvoteTotal = 0;
        addedSub.completed = false;
        addedSub.upvoteTotal = amount;

        allSubmissions[newSub] = addedSub;
        allSubmissions[newSub].balances[msg.sender] = amount;
        allSubmissions[newSub].promoters.push(msg.sender);
        userBase[msg.sender].contributionScore += amount;
        userBase[msg.sender].postIndices.push(newSub);

        emit _SubmissionUploaded(newSub);
    }

    function upvoteSub (uint submissionIndex, uint amount) public payable incomplete(allSubmissions[submissionIndex]) timeTested(allSubmissions[submissionIndex]) {
        token.transferFrom(msg.sender, address(this), amount);
        allSubmissions[submissionIndex].promoters.push(msg.sender);
        allSubmissions[submissionIndex].balances[msg.sender] += amount;
        allSubmissions[submissionIndex].upvoteTotal += amount;
        userBase[msg.sender].contributionScore += amount;
        emit _UpvoteCast(msg.sender, amount);
    }

    function downvoteSub (uint submissionIndex, uint amount) public payable incomplete(allSubmissions[submissionIndex]) timeTested(allSubmissions[submissionIndex]) {
        token.transferFrom(msg.sender, address(this), amount);
        allSubmissions[submissionIndex].challengers.push(msg.sender);
        allSubmissions[submissionIndex].balances[msg.sender] += amount;
        allSubmissions[submissionIndex].downvoteTotal += amount;
        userBase[msg.sender].contributionScore += amount;
        emit _DownvoteCast(msg.sender, amount);
    }

    function calculateVotes() public {
        //Calculate questions votes and either publishes, rejects, or removes listing (consider adding ratio for majority)
        for (uint i = 0 ; i < allSubmissions.length ; i++) {
            if (allSubmissions[i].expirationTime > now && allSubmissions[i].completed == false) {
                uint ratio = (allSubmissions[i].upvoteTotal*100 / (allSubmissions[i].upvoteTotal + allSubmissions[i].downvoteTotal));
                if (ratio > 59) {
                    submissionPublish(i);
                } else if (ratio < 41) {
                    submissionReject(i);
                } else {
                    removeSubmission(i);
                }
            }
        }
    }
    
    function submissionPublish(uint submissionIndex) internal {
        //Distribute funds to question upvoters and calculate votes for answers
        for (uint i = 0 ; i < allSubmissions[submissionIndex].promoters.length ; i++) {
            uint ratio = ((allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].promoters[i]]*100) / (allSubmissions[submissionIndex].upvoteTotal));
            uint amountWon = (ratio*(allSubmissions[submissionIndex].downvoteTotal));
            token.transfer(allSubmissions[submissionIndex].promoters[i], (amountWon/100));
            allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].promoters[i]] = 0;
        }
        allSubmissions[submissionIndex].completed = true;

        for (i = 0 ; i < allSubmissions[submissionIndex].answers.length ; i++){
            bool keepResponse = calculateResponse(submissionIndex, i);
            if (!keepResponse){
                delete(allSubmissions[submissionIndex].answers[i]);
            }
        }
        
        emit _SubmissionPassed(allSubmissions[submissionIndex].submittedDataIndex);
    }
    
    function submissionReject(uint submissionIndex) internal {
        for (uint i = 0 ; i < allSubmissions[submissionIndex].challengers.length ; i++) {
            uint ratio = ((allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].challengers[i]]*100) / (allSubmissions[submissionIndex].upvoteTotal));
            uint amountWon = (ratio*(allSubmissions[submissionIndex].downvoteTotal));
            token.transfer(allSubmissions[submissionIndex].challengers[i], (amountWon/100));
            allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].challengers[i]] = 0;
        }
        allSubmissions[submissionIndex].completed = true;

        for (i = 0 ; i < allSubmissions[submissionIndex].answers.length ; i++){
            removeResponse(submissionIndex, i);
        }

        emit _SubmissionDenied(allSubmissions[submissionIndex].submittedDataIndex);
    }

    function removeSubmission(uint submissionIndex) public submitterOnly(allSubmissions[submissionIndex]) returns(bool removed) {
        for (uint i = 0 ; i < allSubmissions[submissionIndex].answers.length ; i++){
            removeResponse(submissionIndex, i);
        }
        for (i = 0 ; i < allSubmissions[submissionIndex].promoters.length ; i++) {
            uint share = allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].promoters[i]];
            allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].promoters[i]] = 0;
            token.transfer(allSubmissions[submissionIndex].promoters[i], share);
        }
        for (i = 0 ; i < allSubmissions[submissionIndex].challengers.length; i++) {
            share = allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].challengers[i]];
            allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].challengers[i]] = 0;
            token.transfer(allSubmissions[submissionIndex].challengers[i], allSubmissions[submissionIndex].balances[allSubmissions[submissionIndex].challengers[i]]);
        }
        allSubmissions[submissionIndex].completed = true;
        emit _SubmissionRemoved(allSubmissions[submissionIndex].submittedDataIndex);
        return true;
    }
    
    function addResponse(uint submissionIndex, uint responseIndex, uint amount) public payable incomplete(allSubmissions[submissionIndex]) timeTested(allSubmissions[submissionIndex]) {
        require(amount >= minDeposit);
        token.transferFrom(msg.sender, address(this), amount);

        Answer newAnswer;
        newAnswer.respondent = msg.sender;
        newAnswer.upvoteTotal = amount;
        newAnswer.downvoteTotal = 0;
        newAnswer.index = responseIndex;

        allSubmissions[submissionIndex].answers[responseIndex] = newAnswer;
        allSubmissions[submissionIndex].answers[responseIndex].balances[msg.sender] = amount;
        allSubmissions[submissionIndex].answers[responseIndex].promoters.push(msg.sender);
        userBase[msg.sender].contributionScore += amount;
        emit _ResponseSubmitted(submissionIndex, responseIndex);
    }

    function upvoteResponse(uint submissionIndex, uint responseIndex, uint amount) public payable incomplete(allSubmissions[submissionIndex]) timeTested(allSubmissions[submissionIndex]) {
        token.transferFrom(msg.sender, address(this), amount);
        allSubmissions[submissionIndex].answers[responseIndex].promoters.push(msg.sender);
        allSubmissions[submissionIndex].answers[responseIndex].balances[msg.sender] += amount;
        allSubmissions[submissionIndex].answers[responseIndex].upvoteTotal += amount;
        userBase[msg.sender].contributionScore += amount;
        emit _UpvoteCast(msg.sender, amount);
    }

    function downvoteResponse(uint submissionIndex, uint responseIndex, uint amount) public payable timeTested(allSubmissions[submissionIndex]) {
        token.transferFrom(msg.sender, address(this), amount);
        allSubmissions[submissionIndex].answers[responseIndex].challengers.push(msg.sender);
        allSubmissions[submissionIndex].answers[responseIndex].balances[msg.sender] += amount;
        allSubmissions[submissionIndex].answers[responseIndex].downvoteTotal += amount;
        userBase[msg.sender].contributionScore += amount;
        emit _DownvoteCast(msg.sender, amount);
    }

    function calculateResponse(uint submissionIndex, uint responseIndex) internal returns (bool publish) {
        uint ratio = (allSubmissions[submissionIndex].answers[responseIndex].upvoteTotal*100 / (allSubmissions[submissionIndex].answers[responseIndex].upvoteTotal + allSubmissions[submissionIndex].answers[responseIndex].downvoteTotal));
        if (ratio > 59) {
            for (uint i = 0 ; i < allSubmissions[submissionIndex].answers[responseIndex].promoters.length ; i++) {
                uint ratioIndiv = ((allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].promoters[i]]*100) / (allSubmissions[submissionIndex].answers[responseIndex].upvoteTotal));
                uint amountWon = (ratioIndiv*(allSubmissions[submissionIndex].answers[responseIndex].downvoteTotal));
                token.transfer(allSubmissions[submissionIndex].answers[responseIndex].promoters[i], (amountWon/100));
                allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].promoters[i]] = 0;
            }
            allSubmissions[submissionIndex].answers[responseIndex].challengers = [0];
            allSubmissions[submissionIndex].answers[responseIndex].promoters = [0];
            return true;
        } else if (ratio < 41) {
            for (i = 0 ; i < allSubmissions[submissionIndex].answers[responseIndex].promoters.length ; i++) {
                ratioIndiv = ((allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].promoters[i]]*100) / (allSubmissions[submissionIndex].answers[responseIndex].upvoteTotal));
                amountWon = (ratioIndiv*(allSubmissions[submissionIndex].answers[responseIndex].downvoteTotal));
                token.transfer(allSubmissions[submissionIndex].answers[responseIndex].promoters[i], (amountWon/100));
                allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].promoters[i]] = 0;
            }
            allSubmissions[submissionIndex].answers[responseIndex].challengers = [0];
            allSubmissions[submissionIndex].answers[responseIndex].promoters = [0];
            return false;
        } else {
            removeResponse(submissionIndex, responseIndex);
            return false;
        }
    }

    function removeResponse(uint submissionIndex, uint responseIndex) public responderOnly(allSubmissions[submissionIndex].answers[responseIndex]) returns(bool removed){
        for (uint i = 0 ; i < allSubmissions[submissionIndex].answers[responseIndex].promoters.length ; i++) {
            uint share = allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].promoters[i]];
            allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].promoters[i]] = 0;
            token.transfer(allSubmissions[submissionIndex].answers[responseIndex].promoters[i], share);
        }
        for (i = 0 ; i < allSubmissions[submissionIndex].answers[responseIndex].challengers.length; i++) {
            share = allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].challengers[i]];
            allSubmissions[submissionIndex].answers[responseIndex].balances[allSubmissions[submissionIndex].answers[responseIndex].challengers[i]] = 0;
            token.transfer(allSubmissions[submissionIndex].answers[responseIndex].challengers[i], share);
        }
        allSubmissions[submissionIndex].answers[responseIndex].promoters = [0];
        allSubmissions[submissionIndex].answers[responseIndex].challengers = [0];
        emit _ResponseRemoved(submissionIndex, responseIndex);
        return true;
    }

    //Freindship
    function addFriend(address friend) public {
        for (uint i = 0 ; i < userBase[msg.sender].friends.length ; i++){
            if(userBase[msg.sender].friends[i] == friend){
                break;
            }
        }
        userBase[msg.sender].friends.push(friend);
        userBase[msg.sender].contributionScore += 100;
        emit _FriendAdded(msg.sender, friend);
    }

    function removeFriend(address hater) public {
        userBase[msg.sender].contributionScore -= 100;
        for (uint i = 0 ; i < userBase[msg.sender].friends.length ; i++){
            if(userBase[msg.sender].friends[i] == hater){
                delete(userBase[msg.sender].friends[i]);
                break;
            }
        }
        emit _FriendRemoved(msg.sender, hater);
    }

    //Get Functions
    function getExpirationTime(uint givenDataIndex) public view returns(uint expirationTime) {
        return (allSubmissions[givenDataIndex].expirationTime);
    }

    function getSubTotalVotes(uint givenDataIndex) public view returns(uint voteTotal) {
        return (allSubmissions[givenDataIndex].upvoteTotal + allSubmissions[givenDataIndex].downvoteTotal);
    }

    function getQuestionProvider(uint givenDataIndex) public view returns(string name) {
        return (userBase[allSubmissions[givenDataIndex].submitter].name);
    }

    function getAnswerVotes(uint givenSubmissionIndex, uint givenResponseIndex) public view returns(uint voteTotal) {
        return (allSubmissions[givenSubmissionIndex].answers[givenResponseIndex].upvoteTotal + allSubmissions[givenSubmissionIndex].answers[givenResponseIndex].downvoteTotal);
    }

    function getAnswerProvider(uint givenSubmissionIndex, uint givenResponseIndex) public view returns(string name) {
        return (userBase[allSubmissions[givenSubmissionIndex].answers[givenResponseIndex].respondent].name);
    }
    
    function getMinDeposit() public view returns(uint amount) {
        return (minDeposit);
    }
    
    function getUserName(address user) public returns (string name) {
        return (userBase[user].name);
    }

    function getFriendsList(address user) public returns (address[] list) {
        return (userBase[user].friends);
    }
    
    function getContributionScore(address user) public returns (uint score) {
        return (userBase[user].contributionScore);
    }

    function getUserPosts(address user) public returns (uint[] posts) {
        return (userBase[user].postIndices);
    }

    function setMinDeposit(uint amount) public ownerOnly {
        minDeposit = amount;
    }
}