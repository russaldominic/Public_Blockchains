// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract InsuranceSmartContract {

    struct policyholder
    {
        address holder_addr;
        uint256 premium_amt;
        uint256 coverage_amt;
        uint256 issue_date;
        uint256 expiry_date;
        policystatus status;
    }

    struct policyclaim
    {
        address holder_addr;
        uint256 claim_amt;
        string claim_reason;
        policyclaimstatus claim_status;
    }

    uint256 public policy_cnt=0;   // Holds the total number of policy
    uint256 public submitted_claim_cnt=0;   // Holds the total number of submitted claims
    uint256 public approved_claim_cnt=0;   // Holds the total number of apporved claims
    address public approver;      // Deployer will be the approver
    address public scaddress;     // SC address used to settle the claims

    enum policystatus
    {
        DEACTIVE,
        ACTIVE
    } policystatus status;

    enum policyclaimstatus
    {
        PENDING,
        APPROVED,
        REJECTED,
        PAID
    } 

    // Events
    event PolicyIssued (address holder_addr, uint256 premium_amt, uint256 coverage_amt, uint256 issueDate, uint256 expiryDate);
    event PremiumPaid (address holder_addr, uint256 premium_amt);
    event ClaimSubmitted (address holder_addr, uint256 claim_amt);
    event ClaimApprovalStatus (address holder_addr, policyclaimstatus appr_status);
    event ClaimPaid (address holder_addr, policyclaimstatus claim_status);

    mapping (address=>policyholder) public policyholderlist;    // To store the policy holder
    mapping (address=>bool) public policyAdd_Exists;            // To store policy address exists or not
    mapping (address=>bool) public isAuthorized;  // Holds the list of predefined authorized insurers (addresses) who can issue policy
    policyclaim[] public policyclaimlist;    // To store the policy claim holder

    constructor()
    {
        // Predefined addresses who can issue policy along with the SC deployer
        isAuthorized[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        isAuthorized[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        isAuthorized[msg.sender] = true;    // Include the smart contract deployer also as authorized

        // Approver
        approver = msg.sender;  // deployer address is considered as approver
    }

    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender], "Not authorized");
        _;
    }

    // function to issue new insurance policies
    // inputs (4 parameters) : policyholder's - address, premium amount, coverage amount and policy duration
    function issuePolicy(address holder_addr, uint256 premium_amt, uint256 coverage_amt, uint256 policy_dur_days) public onlyAuthorized
    {
        // Store the policy holder in the list
        policyholderlist[holder_addr].holder_addr = holder_addr;
        policyholderlist[holder_addr].premium_amt = premium_amt;
        policyholderlist[holder_addr].coverage_amt = coverage_amt;
        policyholderlist[holder_addr].issue_date = block.timestamp;
        policyholderlist[holder_addr].expiry_date = policyholderlist[holder_addr].issue_date + (policy_dur_days * 1 days);  // for days convertion
        policyholderlist[holder_addr].status = policystatus.ACTIVE;  // Set the policy status to ACTIVE at the time of issue

        policyAdd_Exists[holder_addr] = true;   // Set the address exists
        policy_cnt++;
        emit PolicyIssued (holder_addr, premium_amt, coverage_amt, policyholderlist[holder_addr].issue_date, policyholderlist[holder_addr].expiry_date);
    }

    // function to pay premium by the policy holder (anyone can pay)
    // inputs (2 parameters) : policy holder address and premium amount to pay (considering anyone can pay the premium for the particular policy holder)
    // 1st => verifies the policy existance
    // 2nd => verifies whether the policy is active or not
    // 3rd => verifies the premium amt matches the policies premium amt
    function payPremium(address holder_addr1, uint256 premium_amt) public 
    {
        // 1st => verifies the policy existance
        require(policyholderlist[holder_addr1].holder_addr != address(0), "Policy does not exists");
        // 2nd => verifies whether the policy is active or not
        require (policyholderlist[holder_addr1].status == policystatus.ACTIVE, "Policy is NOT ACTIVE");
        // 3rd => verifies the premium amt matches the policies premium amt
        require (policyholderlist[holder_addr1].premium_amt == premium_amt , "Premium Amount is NOT Accepted");

        policyholderlist[holder_addr1].status = policystatus.ACTIVE;
        emit PremiumPaid (holder_addr1, premium_amt);
    }

    // function to submit the claim by the policy holder (registered policy holder)
    // inputs (2 parameters) : claim amount and reason for claim (considering only the policy holder claims
    // 1st => verifies the policy existance
    // 2nd => verifies whether the policy is active or not
    // if policy is active, update the details
    function submitClaim(uint256 _claim_no, uint256 claim_amt_ETH, string memory claim_reason) public 
    {
        require(policyholderlist[msg.sender].holder_addr != address(0), "Policy does not exists");
        // Check for the claim person really holds the policy
        require (policyholderlist[msg.sender].status == policystatus.ACTIVE, "Policy is NOT ACTIVE");
       
        // Update the record
        // claim number is subtracted by 1 to start claim no. from 1
        policyclaimlist.push();
        policyclaimlist[_claim_no-1].holder_addr = msg.sender;
        policyclaimlist[_claim_no-1].claim_amt = claim_amt_ETH * 1 ether;  // convert to wei
        policyclaimlist[_claim_no-1].claim_reason = claim_reason;
        policyclaimlist[_claim_no-1].claim_status = policyclaimstatus.PENDING;

        submitted_claim_cnt++;

        emit ClaimSubmitted (msg.sender, claim_amt_ETH);
    }

    // function to approve the claim by the Approver (who deploys the smart contract)
    // inputs (1 parameter) : Approver Apply status
    // 1st => verifies the approver is the deployer of smart contract
    // 2nd => check if any claims are waiting in queue for approval
    // 3rd => verifies whether the policy claim status is Pending
    function approveClaim(uint256 _claim_no, policyclaimstatus applyapprstatus) public 
    {
        require(msg.sender == approver, "Not the deployer/approver to approve the claim.");
        require(submitted_claim_cnt>0, "No Claims are submitted");
        require(_claim_no>0 && _claim_no<=submitted_claim_cnt, "Enter the proper claim number to approve");
        // Check for the claim really is in status - pending
        require(policyclaimlist[_claim_no-1].claim_status == policyclaimstatus.PENDING, "Claim is either already APPROVED or REJECTED");

        // Update the record
        policyclaimlist[_claim_no-1].claim_status = applyapprstatus;    // approve or Reject based on approver

        emit ClaimApprovalStatus (policyclaimlist[_claim_no-1].holder_addr, applyapprstatus);
    }

    // function to pay the claims to the policy holders
    function payClaim(uint256 _claim_no) public payable 
    {
        require(msg.sender == approver, "Not the deployer/approver to approve the claim.");
        require(submitted_claim_cnt>0, "No Claims available");
        require(_claim_no>0 && _claim_no<=submitted_claim_cnt, "Enter the proper claim number to approve");
        require(policyclaimlist[_claim_no-1].claim_status == policyclaimstatus.APPROVED, "Claim is not in Approved state");
        require(policyclaimlist[_claim_no-1].claim_amt <= scaddress.balance, "No sufficient fund in the smart contract");

        (bool success, ) = payable(policyclaimlist[_claim_no-1].holder_addr).call{value: (uint256) (policyclaimlist[_claim_no-1].claim_amt)}("");   // convert ether value into wei for processing
        require(success, "Transfer failed");

        policyclaimlist[_claim_no-1].claim_status = policyclaimstatus.PAID;
        submitted_claim_cnt--;    // Once paid successfuly set decrement the claim count

        emit ClaimPaid (policyclaimlist[_claim_no-1].holder_addr, policyclaimstatus.PAID);
    }

    // function to receive ether to settle the claims to the policy holders
    function transferEtherSC(address payable _scaddress) public payable 
    {
        scaddress = _scaddress;
        //, is indication that ignoring remaining values
        //msg.value --> the amount of EThers
        (bool status1,)=_scaddress.call{value:msg.value}("Sending Ethers");
        require (status1, "Fallback Function call failed");
    }

    fallback() external payable {}
    
    receive() external payable {}

    // function to get the balance in the Smart Contract
    function getbalance() public view returns(uint)
    {
        return scaddress.balance;
    }

}
