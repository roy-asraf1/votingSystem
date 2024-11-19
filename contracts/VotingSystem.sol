// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract VotingSystem {
    enum Role { None, Manager, Customer }
    enum RequestStatus { InProcess, Approved, Rejected }

    struct User {
        string username;
        Role role;
    }

    struct Vote {
        uint256 id;
        string question;
        string[] options;
        uint256[] votesPerOption;
        uint256 closingDate;
        bool isOpen;
        mapping(address => bool) hasVoted;
    }

    struct WithdrawalRequest {
        uint256 id;
        address payable requester;
        string description;
        uint256 amount;
        string attachment; // Could be a URL or hash
        RequestStatus status;
    }

    address public owner;
    uint256 public voteCount;
    uint256 public requestCount;
    uint256 public companyBalance;

    mapping(address => User) public authorizedUsers;
    mapping(address => bool) public admins; // Mapping for admin roles
    mapping(uint256 => Vote) public votes;
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;

    address[] public userAddresses;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier onlyManager() {
        require(
            authorizedUsers[msg.sender].role == Role.Manager,
            "Not a manager"
        );
        _;
    }

    modifier onlyAuthorized() {
        require(
            authorizedUsers[msg.sender].role != Role.None,
            "Not authorized"
        );
        _;
    }

    event UserAdded(address user, string username, Role role);
    event UserRemoved(address user);
    event VoteCreated(uint256 voteId, string question);
    event VoteClosed(uint256 voteId);
    event Voted(uint256 voteId, address voter, uint256 option);

    // New Events
    event FundsAdded(address manager, uint256 amount);
    event WithdrawalRequestCreated(uint256 requestId, address requester, uint256 amount);
    event WithdrawalRequestApproved(uint256 requestId);
    event WithdrawalRequestRejected(uint256 requestId);

    constructor() {
        owner = msg.sender;
        authorizedUsers[msg.sender] = User("Owner", Role.Manager);
        admins[msg.sender] = true; // Set owner as an admin
        userAddresses.push(msg.sender);
    }

    // Owner functions
    function addUser(
        address _user,
        string memory _username,
        Role _role
    ) public onlyManager {
        require(
            authorizedUsers[_user].role == Role.None,
            "User already exists"
        );
        authorizedUsers[_user] = User(_username, _role);
        userAddresses.push(_user);
        emit UserAdded(_user, _username, _role);

        if (_role == Role.Manager) {
            admins[_user] = true; // Automatically add managers as admins
        }
    }

    function removeUser(address _user) public onlyManager {
        require(
            authorizedUsers[_user].role != Role.None,
            "User does not exist"
        );
        delete authorizedUsers[_user];

        // Remove the user address from userAddresses array
        for (uint i = 0; i < userAddresses.length; i++) {
            if (userAddresses[i] == _user) {
                userAddresses[i] = userAddresses[userAddresses.length - 1];
                userAddresses.pop();
                break;
            }
        }
        emit UserRemoved(_user);
    }

    // Manager functions
    function createVote(
        string memory _question,
        string[] memory _options,
        uint256 _closingDate
    ) public onlyManager {
        require(_options.length >= 2, "At least two options required");
        require(
            _closingDate > block.timestamp,
            "Closing date must be in the future"
        );

        Vote storage newVote = votes[voteCount];
        newVote.id = voteCount;
        newVote.question = _question;
        newVote.options = _options;
        newVote.closingDate = _closingDate;
        newVote.isOpen = true;
        newVote.votesPerOption = new uint256[](_options.length);

        voteCount++;
        emit VoteCreated(newVote.id, _question);
    }

    function closeVote(uint256 _voteId) public onlyManager {
        Vote storage voteInstance = votes[_voteId];
        require(voteInstance.isOpen, "Vote already closed");
        voteInstance.isOpen = false;
        emit VoteClosed(_voteId);
    }

    // Customer functions
    function vote(uint256 _voteId, uint256 _optionIndex)
        public
        onlyAuthorized
    {
        Vote storage voteInstance = votes[_voteId];
        require(voteInstance.isOpen, "Vote is closed");
        require(
            block.timestamp <= voteInstance.closingDate,
            "Voting period has ended"
        );
        require(
            !voteInstance.hasVoted[msg.sender],
            "Already voted in this vote"
        );
        require(
            _optionIndex < voteInstance.options.length,
            "Invalid option"
        );

        voteInstance.votesPerOption[_optionIndex]++;
        voteInstance.hasVoted[msg.sender] = true;
        emit Voted(_voteId, msg.sender, _optionIndex);
    }

    // Financial Management Functions

    // Managers can add funds to the company account
    function addFunds() public payable onlyManager {
        require(msg.value > 0, "Amount must be greater than zero");
        companyBalance += msg.value;
        emit FundsAdded(msg.sender, msg.value);
    }

    // Managers can view the current company balance
    function getCompanyBalance() public view onlyManager returns (uint256) {
        return companyBalance;
    }

    // Customers can create withdrawal requests
    function createWithdrawalRequest(
        string memory _description,
        uint256 _amount,
        string memory _attachment
    ) public onlyAuthorized {
        require(authorizedUsers[msg.sender].role == Role.Customer, "Only customers can create withdrawal requests");
        require(_amount > 0, "Amount must be greater than zero");

        WithdrawalRequest storage newRequest = withdrawalRequests[requestCount];
        newRequest.id = requestCount;
        newRequest.requester = payable(msg.sender);
        newRequest.description = _description;
        newRequest.amount = _amount;
        newRequest.attachment = _attachment;
        newRequest.status = RequestStatus.InProcess;

        emit WithdrawalRequestCreated(requestCount, msg.sender, _amount);

        requestCount++;
    }

    // Managers can approve withdrawal requests
    function approveWithdrawalRequest(uint256 _requestId) public onlyManager {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        require(request.status == RequestStatus.InProcess, "Request is not in process");
        require(companyBalance >= request.amount, "Insufficient company balance");

        request.status = RequestStatus.Approved;
        companyBalance -= request.amount;
        request.requester.transfer(request.amount);

        emit WithdrawalRequestApproved(_requestId);
    }

    // Managers can reject withdrawal requests
    function rejectWithdrawalRequest(uint256 _requestId) public onlyManager {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        require(request.status == RequestStatus.InProcess, "Request is not in process");

        request.status = RequestStatus.Rejected;

        emit WithdrawalRequestRejected(_requestId);
    }

    // Public functions to get withdrawal request details
    function getWithdrawalRequest(uint256 _requestId)
        public
        view
        returns (
            uint256 id,
            address requester,
            string memory description,
            uint256 amount,
            string memory attachment,
            RequestStatus status
        )
    {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        return (
            request.id,
            request.requester,
            request.description,
            request.amount,
            request.attachment,
            request.status
        );
    }

    function getRequestCount() public view returns (uint256) {
        return requestCount;
    }

    // Public functions
    function getVoteDetails(uint256 _voteId)
        public
        view
        returns (
            uint256 id,
            string memory question,
            string[] memory options,
            uint256[] memory votesPerOption,
            uint256 closingDate,
            bool isOpen
        )
    {
        Vote storage voteInstance = votes[_voteId];
        return (
            voteInstance.id,
            voteInstance.question,
            voteInstance.options,
            voteInstance.votesPerOption,
            voteInstance.closingDate,
            voteInstance.isOpen
        );
    }

    function hasUserVoted(uint256 _voteId, address _user)
        public
        view
        returns (bool)
    {
        return votes[_voteId].hasVoted[_user];
    }

    function getUserRole(address _user) public view returns (Role) {
        return authorizedUsers[_user].role;
    }

    function getAllUsers() public view returns (address[] memory) {
        uint activeUserCount = 0;
        for (uint i = 0; i < userAddresses.length; i++) {
            if (authorizedUsers[userAddresses[i]].role != Role.None) {
                activeUserCount++;
            }
        }

        address[] memory activeUsers = new address[](activeUserCount);
        uint index = 0;
        for (uint i = 0; i < userAddresses.length; i++) {
            if (authorizedUsers[userAddresses[i]].role != Role.None) {
                activeUsers[index] = userAddresses[i];
                index++;
            }
        }

        return activeUsers;
    }

    // Add a function to check user authorization for a specific vote
    function isUserAuthorized(uint256 _voteId, address _user) public view returns (bool) {
        return authorizedUsers[_user].role != Role.None && !votes[_voteId].hasVoted[_user];
    }

    // Add a function to return the number of votes
    function getVotesCount() public view returns (uint256) {
        return voteCount;
    }

    function getUsername(address _user) public view returns (string memory) {
        require(authorizedUsers[_user].role != Role.None, "User not found");
        return authorizedUsers[_user].username;
    }
}