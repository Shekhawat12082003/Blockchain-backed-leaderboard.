// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Blockchain-backed Leaderboard
 * @dev Smart contract for maintaining decentralized leaderboards with tamper-proof scores
 */
contract BlockchainLeaderboard {
    // Contract owner
    address public owner;
    
    // Struct to store user information
    struct User {
        string username;
        uint256 score;
        uint256 timestamp;
        bool exists;
    }
    
    // Struct to store leaderboard information
    struct LeaderboardInfo {
        string name;
        string description;
        uint256 createdAt;
        bool active;
    }
    
    // Mapping from leaderboard ID to leaderboard information
    mapping(uint256 => LeaderboardInfo) public leaderboards;
    
    // Mapping from leaderboard ID to mapping of user addresses to user information
    mapping(uint256 => mapping(address => User)) public leaderboardEntries;
    
    // Mapping from leaderboard ID to array of user addresses for easy iteration
    mapping(uint256 => address[]) public leaderboardUsers;
    
    // Mapping to track admin addresses
    mapping(address => bool) public admins;
    
    // Leaderboard counter
    uint256 public leaderboardCount;
    
    // Events
    event LeaderboardCreated(uint256 indexed leaderboardId, string name, string description);
    event ScoreUpdated(uint256 indexed leaderboardId, address indexed user, uint256 score);
    event LeaderboardStatusChanged(uint256 indexed leaderboardId, bool active);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event UserRemoved(uint256 indexed leaderboardId, address indexed user);
    event UserRenamed(uint256 indexed leaderboardId, address indexed user, string newUsername);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
    
    modifier onlyAdminOrOwner() {
        require(msg.sender == owner || admins[msg.sender], "Only admins or owner can call this function");
        _;
    }
    
    modifier leaderboardExists(uint256 leaderboardId) {
        require(leaderboardId < leaderboardCount, "Leaderboard does not exist");
        _;
    }
    
    modifier activeLeaderboard(uint256 leaderboardId) {
        require(leaderboards[leaderboardId].active, "Leaderboard is not active");
        _;
    }
    
    /**
     * @dev Constructor that sets the owner of the contract
     */
    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
        emit AdminAdded(msg.sender);
    }
    
    /**
     * @dev Creates a new leaderboard
     * @param name Name of the leaderboard
     * @param description Description of the leaderboard
     * @return leaderboardId ID of the newly created leaderboard
     */
    function createLeaderboard(string memory name, string memory description) external onlyAdminOrOwner returns (uint256) {
        uint256 leaderboardId = leaderboardCount;
        
        leaderboards[leaderboardId] = LeaderboardInfo({
            name: name,
            description: description,
            createdAt: block.timestamp,
            active: true
        });
        
        leaderboardCount++;
        
        emit LeaderboardCreated(leaderboardId, name, description);
        
        return leaderboardId;
    }
    
    /**
     * @dev Updates or adds a user's score to a leaderboard
     * @param leaderboardId ID of the leaderboard
     * @param user Address of the user
     * @param username Username of the user
     * @param score Score to set for the user
     */
    function updateScore(uint256 leaderboardId, address user, string memory username, uint256 score) 
        external 
        onlyAdminOrOwner 
        leaderboardExists(leaderboardId) 
        activeLeaderboard(leaderboardId) 
    {
        bool newUser = !leaderboardEntries[leaderboardId][user].exists;
        
        leaderboardEntries[leaderboardId][user] = User({
            username: username,
            score: score,
            timestamp: block.timestamp,
            exists: true
        });
        
        if (newUser) {
            leaderboardUsers[leaderboardId].push(user);
        }
        
        emit ScoreUpdated(leaderboardId, user, score);
    }
    
    /**
     * @dev Allows a user to submit their own score (can be restricted by admin verification)
     * @param leaderboardId ID of the leaderboard
     * @param username Username of the user
     * @param score Score to set for the user
     */
    function submitScore(uint256 leaderboardId, string memory username, uint256 score) 
        external 
        leaderboardExists(leaderboardId) 
        activeLeaderboard(leaderboardId) 
    {
        address user = msg.sender;
        bool newUser = !leaderboardEntries[leaderboardId][user].exists;
        
        leaderboardEntries[leaderboardId][user] = User({
            username: username,
            score: score,
            timestamp: block.timestamp,
            exists: true
        });
        
        if (newUser) {
            leaderboardUsers[leaderboardId].push(user);
        }
        
        emit ScoreUpdated(leaderboardId, user, score);
    }
    
    /**
     * @dev Activates or deactivates a leaderboard
     * @param leaderboardId ID of the leaderboard
     * @param active Whether the leaderboard should be active
     */
    function setLeaderboardStatus(uint256 leaderboardId, bool active) 
        external 
        onlyAdminOrOwner 
        leaderboardExists(leaderboardId) 
    {
        leaderboards[leaderboardId].active = active;
        emit LeaderboardStatusChanged(leaderboardId, active);
    }
    
    /**
     * @dev Adds a new admin
     * @param admin Address of the new admin
     */
    function addAdmin(address admin) external onlyOwner {
        require(!admins[admin], "Address is already an admin");
        admins[admin] = true;
        emit AdminAdded(admin);
    }
    
    /**
     * @dev Removes an admin
     * @param admin Address of the admin to remove
     */
    function removeAdmin(address admin) external onlyOwner {
        require(admin != owner, "Cannot remove owner as admin");
        require(admins[admin], "Address is not an admin");
        admins[admin] = false;
        emit AdminRemoved(admin);
    }
    
    /**
     * @dev Removes a user from a leaderboard
     * @param leaderboardId ID of the leaderboard
     * @param user Address of the user to remove
     */
    function removeUser(uint256 leaderboardId, address user) 
        external 
        onlyAdminOrOwner 
        leaderboardExists(leaderboardId) 
    {
        require(leaderboardEntries[leaderboardId][user].exists, "User does not exist in leaderboard");
        
        // Remove user from mapping
        delete leaderboardEntries[leaderboardId][user];
        
        // Remove user from array
        address[] storage users = leaderboardUsers[leaderboardId];
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == user) {
                // Replace with last element and pop
                users[i] = users[users.length - 1];
                users.pop();
                break;
            }
        }
        
        emit UserRemoved(leaderboardId, user);
    }
    
    /**
     * @dev Updates a user's username
     * @param leaderboardId ID of the leaderboard
     * @param user Address of the user
     * @param newUsername New username for the user
     */
    function updateUsername(uint256 leaderboardId, address user, string memory newUsername) 
        external 
        onlyAdminOrOwner 
        leaderboardExists(leaderboardId) 
    {
        require(leaderboardEntries[leaderboardId][user].exists, "User does not exist in leaderboard");
        
        leaderboardEntries[leaderboardId][user].username = newUsername;
        
        emit UserRenamed(leaderboardId, user, newUsername);
    }
    
    /**
     * @dev Gets the top N users from a leaderboard
     * @param leaderboardId ID of the leaderboard
     * @param n Number of top users to retrieve
     * @return topUsers Array of top user addresses
     * @return scores Array of scores corresponding to the top users
     * @return usernames Array of usernames corresponding to the top users
     */
    function getTopUsers(uint256 leaderboardId, uint256 n) 
        external 
        view 
        leaderboardExists(leaderboardId) 
        returns (address[] memory topUsers, uint256[] memory scores, string[] memory usernames) 
    {
        address[] memory users = leaderboardUsers[leaderboardId];
        uint256 length = users.length < n ? users.length : n;
        
        topUsers = new address[](length);
        scores = new uint256[](length);
        usernames = new string[](length);
        
        // Copy users to a memory array for sorting
        address[] memory tempUsers = new address[](users.length);
        for (uint i = 0; i < users.length; i++) {
            tempUsers[i] = users[i];
        }
        
        // Sort users by score (simple bubble sort)
        for (uint i = 0; i < tempUsers.length; i++) {
            for (uint j = i + 1; j < tempUsers.length; j++) {
                if (leaderboardEntries[leaderboardId][tempUsers[i]].score < leaderboardEntries[leaderboardId][tempUsers[j]].score) {
                    address temp = tempUsers[i];
                    tempUsers[i] = tempUsers[j];
                    tempUsers[j] = temp;
                }
            }
        }
        
        // Fill result arrays with top n users
        for (uint i = 0; i < length; i++) {
            topUsers[i] = tempUsers[i];
            scores[i] = leaderboardEntries[leaderboardId][tempUsers[i]].score;
            usernames[i] = leaderboardEntries[leaderboardId][tempUsers[i]].username;
        }
        
        return (topUsers, scores, usernames);
    }
    
    /**
     * @dev Gets user information from a leaderboard
     * @param leaderboardId ID of the leaderboard
     * @param user Address of the user
     * @return username Username of the user
     * @return score Score of the user
     * @return timestamp Timestamp of the last score update
     * @return exists Whether the user exists in the leaderboard
     */
    function getUserInfo(uint256 leaderboardId, address user) 
        external 
        view 
        leaderboardExists(leaderboardId) 
        returns (string memory username, uint256 score, uint256 timestamp, bool exists) 
    {
        User memory userInfo = leaderboardEntries[leaderboardId][user];
        return (userInfo.username, userInfo.score, userInfo.timestamp, userInfo.exists);
    }
    
    /**
     * @dev Gets the number of users in a leaderboard
     * @param leaderboardId ID of the leaderboard
     * @return count Number of users in the leaderboard
     */
    function getUserCount(uint256 leaderboardId) 
        external 
        view 
        leaderboardExists(leaderboardId) 
        returns (uint256 count) 
    {
        return leaderboardUsers[leaderboardId].length;
    }
    
    /**
     * @dev Gets all users in a leaderboard
     * @param leaderboardId ID of the leaderboard
     * @return users Array of user addresses
     */
    function getAllUsers(uint256 leaderboardId) 
        external 
        view 
        leaderboardExists(leaderboardId) 
        returns (address[] memory users) 
    {
        return leaderboardUsers[leaderboardId];
    }
    
    /**
     * @dev Gets leaderboard information
     * @param leaderboardId ID of the leaderboard
     * @return name Name of the leaderboard
     * @return description Description of the leaderboard
     * @return createdAt Timestamp when the leaderboard was created
     * @return active Whether the leaderboard is active
     */
    function getLeaderboardInfo(uint256 leaderboardId) 
        external 
        view 
        leaderboardExists(leaderboardId) 
        returns (string memory name, string memory description, uint256 createdAt, bool active) 
    {
        LeaderboardInfo memory info = leaderboards[leaderboardId];
        return (info.name, info.description, info.createdAt, info.active);
    }
    
    /**
     * @dev Transfers ownership of the contract
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
        // Ensure the new owner is also an admin
        if (!admins[newOwner]) {
            admins[newOwner] = true;
            emit AdminAdded(newOwner);
        }
    }
}
