// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract loteria is ERC20, Ownable {
    //Token administration

    // NFT Contract address
    address public nft;

    // Constructor
    constructor() ERC20("Loteria", "JA"){
        _mint(address(this),  1000);
        nft = address(new mainERC721());
    }

    //Winner of the lottery prize
    address public winner;

    // User registry
    mapping(address => address) public user_contract;

    // ERC20 Token Price
    function tokenPrice(uint256 _numTokens) internal pure returns(uint256) {
        return _numTokens * (1 ether);
    }

    // Visualize tokens balance of user
    function balanceTokens(address _account) public view returns(uint){
        return balanceOf(_account);
    }

        // Visualize tokens balance of Smart Contract
    function balanceTokensSC() public view returns(uint){
        return balanceOf(address(this));
    }

    //Visualize balance of ethers of Smart Contract
    function balanceEthersSC() public view returns (uint256){
        return address(this).balance / 10**18;
    }

    // Generate new ERC20 Tokens
    function mint(uint256 _quantity) public onlyOwner{
        _mint(address(this), _quantity);
    }

    // User Registration
    function register() internal {
        address addr_personal_contract = address(new TicketsNFTs(msg.sender, address(this), nft));
        user_contract[msg.sender] = addr_personal_contract;
    }

    // Returns info about user
    function usersInfo(address _account) public view returns(address){
        return user_contract[_account];
    }

    // Buy Tokens ERC20
    function buyTokens(uint256 _numTokens) public payable{
        //register user
        if(user_contract[msg.sender] == address(0)){
            register();
        }

        // Price of the tokens 
        uint256 cost = tokenPrice(_numTokens);
        // Evaluate the money spent for tokens
        require(msg.value >= cost, "Buy less or Pay more");
        // Obtain num of available tokens
        uint256 balance = balanceTokensSC();
        require(_numTokens <= balance, "Not enought tokens available.");
        // Devolucion of the rest of the money.
        uint256 returnValue = msg.value - cost;
        // The smart contract returns the rest of the money
        payable(msg.sender).transfer(returnValue);
        // Send tokens to the client/user
        _transfer(address(this), msg.sender, _numTokens);
    }
    
    // Return of Tokens to Smart Contract
    function returnTokens(uint _numTokens) public payable{
        //The number of tokens has to be bigger than 0
        require(_numTokens > 0, "You need to return more than 0 tokens");
        // User has to acreditate that has the tokens
        require(_numTokens <= balanceTokens(msg.sender), "You dont have the tokens you want to return");
        // User Transfer the tokens to the Smart COntract
        _transfer(msg.sender, address(this), _numTokens);
        payable(msg.sender).transfer(tokenPrice(_numTokens));
    }


    // Lottery ADMINISTRATION

    // Lottery Ticket Price (in ERC20)
    uint public ticketPrice = 5;
    // Relation: User who buys -> the number of the tickets
    mapping(address => uint[]) idUser_tickets;
    // Relation: Ticket -> Winner
    mapping(uint => address) ADNTicket;
    // Random number
    uint randNonce = 0;
    // Lottery tickets generated
    uint[] ticketsBuyed;

    // Buy lottery ticket
    function buyTicket(uint _numTickets) public {
        //Total price of tickets to buy
        uint totalPrice = _numTickets * ticketPrice;
        require(totalPrice <= balanceTokens(msg.sender), "Insufficient funds");

        // Transfer tokens from user to Smart Contract
        _transfer(msg.sender, address(this), totalPrice);

        /* Pick the timestamp, msg.sender and Nonce in increment. We use Keccak256 to convert this 
        entries in a random hash, convert this hash to uint and then % 10000 to take the last 5 digits
        giving a random value between 0 and 99999 */

        for (uint i = 0; i < _numTickets; i++){
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 100000;
            randNonce++;
            // Storage of ticket data enlazed with user
            idUser_tickets[msg.sender].push(random);

            // Storage of the Tickets data
            ticketsBuyed.push(random);

            //Asign DNA of ticket to generate a winner
            ADNTicket[random] = msg.sender;

            // Create new NFT for ticket number
            TicketsNFTs(user_contract[msg.sender]).mintTicket(msg.sender, random);
        }
    }

    // Visualize user tickets
    function yourTickets(address _owner) public view returns(uint [] memory){
        return idUser_tickets[_owner];
    }

    // Generate lottery winner
    function generateWinner() public onlyOwner{
        // Declare the long of the array
        uint longitude = ticketsBuyed.length;
        // verify the bought of at least 1 ticket.
        require(ticketsBuyed.length > 0, "No tickets bought");

        // Random election of a number in between [0- longitude]
        uint random = uint(uint(keccak256(abi.encodePacked(block.timestamp))) % longitude);
        // Select random number.
        uint selected = ticketsBuyed[random];
        // Address of lottery owner
        winner = ADNTicket[selected];
        // Send 95% of the money to the winner.
        payable(winner).transfer(address(this).balance * 95 / 100);
        // Send the 5% to the owner
        payable(owner()).transfer(address(this).balance * 5 / 100);

        

    }

}

// NFTs Smart Contract
contract mainERC721 is ERC721{


    address public addressLottery;
    constructor() ERC721("Loteria", "STE"){
        addressLottery = msg.sender;
    }

    // Create NFTs Tokens
    function safeMint(address _owner, uint256 _ticket) public {
        require(msg.sender == loteria(addressLottery).usersInfo(_owner), "You dont have permissions to execute this function");
        _safeMint(_owner, _ticket);
    }


}

contract TicketsNFTs{

    // Relevant Data of the owner
    struct Owner{
        address addressOwner;
        address parentContract;
        address nftContract;
        address userContract;
    }
    // Data structure of type owner
    Owner public owner;

    // Constructor of the child Smart Contract
    constructor(address _owner, address _parentContract, address _nftContract){
        owner = Owner(_owner, _parentContract, _nftContract, address(this));
    }

    // Convert numbers of lottery tickets
    function mintTicket(address _owner, uint _ticket) public {
        require(msg.sender == owner.parentContract,  "You dont have permissions.");
        mainERC721(owner.nftContract).safeMint(_owner, _ticket);
    }

}