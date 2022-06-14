// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Webe is Ownable, ERC721Enumerable {
    using Strings for uint;

    // immutable constants    
    uint16 public constant MAX_SUPPLY = 8888;
    uint public constant WHITLIST_SALE_PRICE = 150 ether;
    uint public constant MAX_MINT = 3;
    uint public constant WHITELIST_MAX_INVITE = 5;
    uint public constant INVITED_MAX_INVITE = 3;

    // enums
    enum MintingStep {
        Initial,
        WhitelistMint,
        PublicMint,
        Rebirth,
        Stable
    }
    enum MintingState {
        Initial,
        Whitelisted,
        Invited
    }
    enum BaseURIType {
        Default,
        One,
        Two,
        Three,
        Four,
        Five
    }

    // structs
    struct AddressState {
        MintingState mintingState;
        uint8 amountMinted;
        uint8 inviteCount;
        address invitor;
    }
    struct TokenState {
        BaseURIType baseURIType;
        mapping(BaseURIType => bool) rebirthHistory;
    }

    // variables
    MintingStep public mintingStep;
    uint public publicSalePrice;
    uint public rebirthPrice;
    uint public startTime;
    address public delegate;

    // mappings
    mapping(address => AddressState) public addressState;
    mapping(uint => TokenState) public tokenState;
    mapping(BaseURIType => string) public baseURI;

    // contructor
    constructor(string memory _defaultBaseURI, address _delegate) ERC721("WEBE", "WBE") {
        baseURI[BaseURIType.Default] = _defaultBaseURI;
        delegate = _delegate;
    }

    // modifiers
    modifier maxSupplyNotExceeded(uint8 _quantity) {
        require(totalSupply() + uint(_quantity) <= uint(MAX_SUPPLY), "Reached max Supply");
        _;
    }
    
    modifier onlyOwnerOf(uint _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "The caller does not own tokenId");
        _;
    }

    modifier onlyHolder() {
        require(balanceOf(msg.sender) > 0, "The account is not holder");
        _;
    }

    modifier callerIsInvitedOrWhitelisted() {
        require(isInvited(msg.sender) || isWhiteListed(msg.sender), "The caller is not invited or whitelisted");
        _;
    }
    
    modifier onlyOwnerOrDelegate(){
        require(owner() == _msgSender() || delegate == _msgSender(), "Ownable: caller is not the owner or delagate");
        _;
    }

    // minting functions
    function mint(uint8 _quantity) external payable callerIsInvitedOrWhitelisted maxSupplyNotExceeded(_quantity) {
        require(mintingStep != MintingStep.PublicMint || mintingStep != MintingStep.WhitelistMint, "Contract state is not in minting state.");
        if(mintingStep == MintingStep.WhitelistMint) require(isInvited(msg.sender) || isWhiteListed(msg.sender), "The caller is not invited or whitelisted");
        require(currentTime() >= startTime, "Whitelist mint has not started yet");
        uint8 amountMintedOnSuccess = getAddressAmountMinted(msg.sender) + _quantity;
        require(amountMintedOnSuccess <= MAX_MINT, "Cannot mint more");
        uint salePrice = mintingStep == MintingStep.WhitelistMint ? WHITLIST_SALE_PRICE : publicSalePrice;
        require(msg.value >= salePrice * _quantity, "Not enough funds");
        setAddressAmountMinted(msg.sender, amountMintedOnSuccess);
        uint totalSupply = totalSupply();
        for(uint i = 0; i<_quantity; i++){
            uint tokenId = totalSupply + i + 1;
            setTokenRebirthHistoryTrue(tokenId, BaseURIType.Default);
            _safeMint(msg.sender, tokenId);
        }
        
    }

    // onlyOwner functions
    function setStartTime(uint _startTime) external onlyOwner {
        startTime = _startTime;
    }

    function setMintingStep(MintingStep _mintingStep) external onlyOwner {
        mintingStep = _mintingStep;
    }

    function setBaseUri(string memory _baseURI, BaseURIType _baseUriType) external onlyOwner {
        baseURI[_baseUriType] = _baseURI;
    }

    function setPublicMintSalePrice(uint _publicSalePrice) external onlyOwner {
        publicSalePrice = _publicSalePrice;
    }

    function setRebirthPrice(uint _rebirthPrice) external onlyOwner {
        rebirthPrice = _rebirthPrice;
    }

    function setDelegate(address _account) external onlyOwner {
        delegate = _account;
    }

    function release() external onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}('');
        require(os);
    }

    // only owner or delegate functions
    function whitelist(address _invitedAccount) external onlyOwnerOrDelegate {
        MintingState mintingState = getAddressMintingState(_invitedAccount);
        require(mintingState == MintingState.Initial, "Account is already whitelisted or invited");
        setAddressMintingState(_invitedAccount, MintingState.Whitelisted);
    }

    function invite(address _invitedAccount) external callerIsInvitedOrWhitelisted onlyHolder {
        MintingState mintingState = getAddressMintingState(_invitedAccount);
        require(mintingState == MintingState.Initial, "Account is already whitelisted or invited");
        require(getAddressMintingState(msg.sender) != MintingState.Invited || getAddressInviteCount(msg.sender) < INVITED_MAX_INVITE, "Account has reached invite limit");
        incrementInviteCount();
        setAddressInvitor(_invitedAccount);
        setAddressMintingState(_invitedAccount, MintingState.Invited);
    }

    function rebirth(uint _tokenId) external onlyOwnerOf(_tokenId) {
        require(mintingStep == MintingStep.Rebirth, "Contract state is not in rebirth.");
        BaseURIType tobeBaseURIType = randomBaseURIType(_tokenId);
        tokenState[_tokenId].baseURIType = tobeBaseURIType;
        setTokenRebirthHistoryTrue(_tokenId, tobeBaseURIType);
    }

    // public view functions
    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "URI query for nonexistent token");

        return string(abi.encodePacked(baseURI[tokenState[_tokenId].baseURIType], _tokenId.toString(), ".json"));
    }

    function getTokenBaseURIType(uint _tokenId) public view returns(BaseURIType) {
        return tokenState[_tokenId].baseURIType;
    }

    function getTokenRebirthHistory(uint _tokenId, BaseURIType _baseURIType) public view returns(bool) {
        return tokenState[_tokenId].rebirthHistory[_baseURIType];
    }

    function getAddressMintingState(address _account) public view returns(MintingState) {
        return addressState[_account].mintingState;
    }

    function getAddressAmountMinted(address _account) public view returns(uint8) {
        return addressState[_account].amountMinted;
    }

    function getAddressInviteCount(address _account) public view returns(uint8) {
        return addressState[_account].inviteCount;
    }

    function getBaseURITypesLeft(uint _tokenId) public view returns(bool[] memory){ 

        bool[] memory baseURITypesLeft = new bool[](6);

        for(uint i = 0; i<6; i++){
            baseURITypesLeft[i] = getTokenRebirthHistory(_tokenId, BaseURIType(i));
        }
        return baseURITypesLeft;
    }

    // internal functions
    function isWhiteListed(address _account) internal view returns(bool) {
        MintingState accountMintingState = getAddressMintingState(_account);
        return accountMintingState == MintingState.Whitelisted;
    }

    function isInvited(address _account) internal view returns(bool) {
        MintingState accountMintingState = getAddressMintingState(_account);
        return accountMintingState == MintingState.Invited;
    }

    function setAddressMintingState(address _account, MintingState _mintingState) internal {
        addressState[_account].mintingState = _mintingState;
    }

    function incrementInviteCount() internal {
        addressState[msg.sender].inviteCount = addressState[msg.sender].inviteCount + 1;
    }

    function setAddressInvitor(address _account) internal {
        addressState[_account].invitor = msg.sender;
    }

    function setAddressAmountMinted(address _account, uint8 _amountMinted) internal {
        addressState[_account].amountMinted = _amountMinted;
    }

    function setTokenRebirthHistoryTrue(uint _tokenId, BaseURIType _baseUriType) internal {
        tokenState[_tokenId].rebirthHistory[_baseUriType] = true;
    }

    function currentTime() internal view returns(uint) {
        return block.timestamp;
    }

    function randomBaseURIType(uint _tokenId) internal view returns (BaseURIType) {
        bool[] memory baseURITypesLeft = getBaseURITypesLeft(_tokenId);
        uint baseURITypesLeftLength = countFalse(baseURITypesLeft);
        require(baseURITypesLeftLength > 0, "Length of BaseURI Types Left has to be greater than 0");
        uint tobeBaseURIType = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % baseURITypesLeftLength;
        uint trueCount;
        for(uint i = 0; i<baseURITypesLeft.length; i++){
            if(baseURITypesLeft[i]){
                trueCount ++;
            }
            else if(i - trueCount == tobeBaseURIType) {
                return BaseURIType(i);
            }
        }
        return BaseURIType(0);
    }

    function countFalse(bool[] memory _booleanArray) internal pure returns(uint){
        uint count;
        for(uint i = 0; i<_booleanArray.length; i++){
            if(!_booleanArray[i]) count++;
        }
        return count;
    }

}