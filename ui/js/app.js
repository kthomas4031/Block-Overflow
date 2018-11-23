const registryContractABI = [];
const contractAddress = ``;
const schedule = require('node-schedule');
let minDeposit, registryContractInstance, account, web3;

window.addEventListener('load', async () => {
    // Modern dapp browsers...
    if (window.ethereum) {
        window.web3 = new Web3(ethereum);
        try {
            // Request account access if needed
            await ethereum.enable();
            // Acccounts now exposed
            web3.eth.sendTransaction({/* ... */});
        } catch (error) {
            // User denied account access...
        }
    }
    // Legacy dapp browsers...
    else if (window.web3) {
        window.web3 = new Web3(web3.currentProvider);
        // Acccounts always exposed
        web3.eth.sendTransaction({/* ... */});
    }
    // Non-dapp browsers...
    else {
        console.log('Non-Ethereum browser detected. You should consider trying MetaMask!');
    }
    console.log(window.web3.eth.accounts);
    account = window.web3.eth.accounts[0];
    console.log(account);
    
    const registryContract = window.web3.eth.contract(registryContractABI);
    registryContractInstance = registryContract.at(contractAddress);
    getSubmissions();
    minDeposit = getMinDeposit();
});

let timedCountdown = schedule.scheduleJob('0 0 * * *', function(){
    registryContractInstance.calculateVotes(account, function(error, transactionHash){
        if (!error){
            console.log(transactionHash);
        } else
            console.log(error);
    })
});

function sendListing(){
    let url = document.getElementById('urlField').value
    //Add Submission to Database
    let amount = document.getElementById('amountField').value
    if(url !== undefined && amount >= minDeposit){
        registryContractInstance.addSubmission(DBINDEX, amount, function(error, transactionHash){
            if(error){
                console.log(transactionHash);
            }
        });
        let image = document.createElement('img');
        image.className = ''; //According to CSS
        image.src = url;
        document.getElementById('after_submission').appendChild(image);
        document.getElementById('amountField').value = '';
        document.getElementById('urlField').value = '';
    }
    else
        console.log("Error: One of two fields not filled out or amount does not meet minimum.");
}

function removeSubmission(index){
    registryContractInstance.removeListing(DBINDEX, function(error,result){
        if (!error){
            //remove submission and answers from database
        } else
            console.log(error);
    });
}

function sendResponse(){
    //Add response to database and contract
}

function removeResponse(){
    //remove from database and contract
}

function getMinDeposit(){
    registryContractInstance.getMinDeposit(account, function(error, result){
        if (!error){
            document.getElementById('minDeposit').value = 'Minimum Deposit: ' + result;
            minDeposit = result;
        } else{
            console.log(error);
            minDeposit = 50;
        }
    });
}

function getAllSubmissions(){
    //for loop iterating through indices in database
}
