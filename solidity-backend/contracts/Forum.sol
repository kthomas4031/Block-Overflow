pragma solidity 0.4.24;

import "./EIP20Interface.sol";


contract Forum {
    //Log tracking
    event _UpvoteCast(address upvoter, uint amount);
    event _DownvoteCast(address downvoter, uint amount);
    event _SubmissionUploaded(uint indexed listingIndex);
    event _SubmissionPassed(uint indexed listingIndex);
    event _SubmissionDenied(uint indexed listingIndex);
    event _ListingSubmitted(uint indexed listingIndex);
    event _ListingRemoved(uint indexed listingIndex);

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
        Answer[26] responses;
    }

    struct Answer {
        address respondent;
        uint upvotes;
        uint downvotes;
        address[] promoters;
        address[] challengers;
        mapping(address => uint) balances;
        //FIGURE OUT INDEX TYPE AND MAKE INDEX VAR
    }


    //Global variables
    uint public minDeposit;
    address private owner;
    EIP20Interface public token;
    Submission[] allSubmissions;


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


    //Functions
    function uploadSub (uint newSub, uint amount) public payable {

    }

    function upvoteSub (uint submissionIndex, uint amount) public payable timeTested(allSubmissions[submissionIndex]){
        token.transferFrom(msg.sender, address(this), amount);
        submissionsMapping[submissionIndex].promoters.push(msg.sender);
        submissionsMapping[submissionIndex].balances[msg.sender] += amount;
        emit _UpvoteCast(msg.sender, amount);
    }

    function downvoteSub (uint submissionIndex, uint amount) public payable timeTested(allSubmissions[submissionIndex]){
        token.transferFrom(msg.sender, address(this), amount);
        submissionsMapping[submissionIndex].challengers.push(msg.sender);
        submissionsMapping[submissionIndex].balances[msg.sender] += amount;
        emit _DownvoteCast(msg.sender, amount);
    }

    function calculateVotes() public {
        //Calculate questions votes and either publishes, rejects, or removes listing (consider adding ratio for majority)
    }
    
    function submissionPublish(uint submissionIndex) internal {
        //Distribute funds to question upvoters and calculate votes for answers
    }
    
    function submissionReject(uint submissionIndex) internal {
        //Distribute funds to question downvoters and calculate votes for answers
    }

    function removeSubmission(uint submissionIndex) public submitterOnly(allSubmissions[submissionIndex]) returns(bool removed){
        //Redistribute funds to question voters and answer voters
    }
    
    //FUNCTIONS FOR UPLOADING, UPVOTING, DOWNVOTING, AND REMOVING ANSWERS
    function addResponse(uint submissionIndex, amount) public payable {

    }

    function upvoteResponse(uint submissionIndex, uint repsonseIndex, uint amount) public payable timeTested(allSubmissions[submissionIndex]) {

    }

    function downvoteResponse(uint submissionIndex, uint responseIndex, uint amount) public payable timeTested(allSubmissions[submissionIndex]) {

    }

    function removeResponse(uint submissionIndex, uint responseIndex) public responderOnly(allSubmissions[submissionIndex].responses[responseIndex]) returns(bool removed){

    }

    //Get Functions
    function getExpirationTime(uint givenDataIndex) public view returns(uint expirationTime){
        return (allSubmissions[givenDataIndex].expirationTime);
    }

    function getSubTotalVotes(uint givenDataIndex) public view returns(uint voteTotal){
        return (allSubmissions[givenDataIndex].upvoteTotal + allSubmissions[givenDataIndex].downvoteTotal);
    }
    
    function getMinDeposit() public view returns(uint amount) {
        return (minDeposit);
    }

    function getResponseTotalVotes(uint givenSubIndex/*add index of responses*/) public view returns(){
        return (allSubmissions[givenSubIndex].responses[givenResponseIndex].upvotes + allSubmissions[givenSubIndex].responses[givenResponseIndex].downvotes)
    }

    function setMinDeposit(uint amount) public ownerOnly {
        minDeposit = amount;
    }
}