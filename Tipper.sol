// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Tipper {
    struct Purse {
        address payable staffId;
        string staffName;
        string aboutStaff;
        string profilePic;
        bool verified;
        uint256 amountDeposited;
        uint256 lastCashout;
    }

    struct Deposit {
        uint256 purseId;
        address depositor;
        string message;
        uint256 depositAmount;
    }

    address payable deployer;
    mapping(address => bool) private isStaff; // verify if user is a staff member
    mapping(address => bool) private hasCreated; // prevent staffs from creating more than one purse
    mapping(uint256 => Purse) private purses;
    mapping(uint256 => Deposit) private deposits;

    // We are using an interger for `idGenerator` because of simplicity. In real life, it can be a complex hashing algorithm
    uint256 private idGenerator = 0;
    uint256 private depositsCounter;
    uint256 cashoutInterval = 30 days;

    constructor() {
        deployer = payable(msg.sender);
    }

    modifier onlyDeployer() {
        require(
            msg.sender == deployer,
            "Only contract deployer can call this function."
        );
        _;
    }

    modifier idIsValid(uint256 _purse_id) {
        require(_purse_id < idGenerator, "Invalid purse ID entered");
        _;
    }

    modifier checkStaffAddress(address _address) {
        require(
            _address != address(0),
            "Staff address can't be an empty address"
        );
        _;
    }

    event AddStaff(address indexed);
    event RemoveStaff(address indexed);

    /// @dev Verify an address as a staff member of organisation
    function addStaff(address _staff_address)
        public
        onlyDeployer
        checkStaffAddress(_staff_address)
    {
        isStaff[_staff_address] = true;
        emit AddStaff(_staff_address);
    }

    /**
     * @dev removes staff's rights from a user
     * @notice Remove an address of a staff member. (This is applicable when the staff leaves the organization)
     * */
    function removeStaff(address _staff_address)
        public
        onlyDeployer
        checkStaffAddress(_staff_address)
    {
        isStaff[_staff_address] = false;
        emit RemoveStaff(_staff_address);
    }

    /// @dev Staff members can create new purse
    /// @notice purse will need to be verified by deployer
    function newPurse(
        string calldata _staff_name,
        string calldata _about_staff,
        string calldata _staff_profile_pic
    ) external {
        require(isStaff[msg.sender], "Only staff members can create new purse");
        require(
            !hasCreated[msg.sender],
            "You can't create more than one purse"
        );
        require(bytes(_staff_name).length > 0, "Empty staff name");
        require(bytes(_about_staff).length > 0, "Empty about staff");
        require(
            bytes(_staff_profile_pic).length > 0,
            "Empty staff profile pic"
        );
        Purse storage purse = purses[idGenerator++];
        purse.staffId = payable(msg.sender);
        purse.staffName = _staff_name;
        purse.aboutStaff = _about_staff;
        purse.profilePic = _staff_profile_pic;
        purse.verified = false;
        purse.amountDeposited = 0;
        purse.lastCashout = block.timestamp;

        hasCreated[msg.sender] = true;
    }

    /// @dev Verify purse created by staffs
    function verifyPurse(uint256 _purse_id)
        public
        onlyDeployer
        idIsValid(_purse_id)
    {
        require(isStaff[purses[_purse_id].staffId], "Not a staff member");
        purses[_purse_id].verified = true;
    }

    /// @dev Customer deposits amount into purse
    /// @notice amount sent with transaction will be the deposit amount sent by customer
    function depositIntoPurse(uint256 _purse_id, string calldata _message)
        public
        payable
        idIsValid(_purse_id)
    {
        Purse storage purse = purses[_purse_id];
        require(purse.staffId != msg.sender, "Can't deposit into own purse");
        require(purse.verified, "Can't deposit into an unverified purse");

        uint newDepositedAmount = purse.amountDeposited + msg.value;
        purse.amountDeposited = newDepositedAmount;
        Deposit storage deposit = deposits[depositsCounter++];
        deposit.purseId = _purse_id;
        deposit.depositor = msg.sender;
        deposit.message = _message;
        deposit.depositAmount = msg.value;
    }

    /// @notice Cash out all funds stored in purse
    /// @notice Owners can only cash out once in 30 days (in production mode only)
    function cashOut(uint256 _purse_id) public payable {
        require(
            purses[_purse_id].staffId == msg.sender,
            "Can't cashout purse because you are not the owner"
        );
        require(
            purses[_purse_id].lastCashout + cashoutInterval >= block.timestamp,
            "Not yet time for cashout"
        );
        Purse storage purse = purses[_purse_id];
        uint256 amount = purse.amountDeposited;
        purse.amountDeposited = 0; // reset state variables before sending funds
        purse.lastCashout = block.timestamp;
        // if registered staff of purse is no longer a staff, the verified status of purse is set to false to prevent future deposits
        // which could result in permanent loss of funds
        if(!isStaff[msg.sender]){
            purse.verified = false;
        }
        (bool sent, ) = purse.staffId.call{value: amount}("");
        require(sent, "Failed to cashout amount to staff wallet");
    }

    /// @dev Check if purse can accept funds before sending
    function canAcceptFunds(uint256 _purse_id)
        public
        view
        idIsValid(_purse_id)
        returns (bool)
    {
        Purse memory purse = purses[_purse_id];
        return purse.verified;
    }

    /// @dev Read details about purse. Only deployer and purse owne can access
    function readPurse(uint256 _purse_id)
        public
        view
        idIsValid(_purse_id)
        returns (
            string memory staffName,
            string memory aboutStaff,
            string memory profilePic,
            bool verified,
            uint256 amountDeposited,
            uint256 lastCashout
        )
    {
        Purse memory purse = purses[_purse_id];
        staffName = purse.staffName;
        aboutStaff = purse.aboutStaff;
        profilePic = purse.profilePic;
        verified = purse.verified;
        amountDeposited = purse.amountDeposited;
        lastCashout = purse.lastCashout;
    }

    // Do nothing if any function is wrongly called
    fallback() external {
        revert();
    }
}
