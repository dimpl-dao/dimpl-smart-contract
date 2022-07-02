// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Webe is Ownable, ERC721Enumerable {
    using Strings for uint;

    uint public constant MAX_SUPPLY = 8888;
    uint public constant POST_WHITELIST_PRESALE_SUPPLY = 4888;
    uint public constant POST_WHITELIST2_SUPPLY = 888;
    uint public constant POST_WHITELIST_SUPPLY = 88;
    uint public constant POST_INITIALIZE_SUPPLY = 8;
    uint public constant MAX_MINT = 5;
    uint public constant WHITELIST_MAX_MINT = 1;
    
    enum MintingStep {
        Initial,
        Whitelist,
        Whitelist2,
        WhitelistPresale,
        Public,
        Rebirth,
        Stable
    }

    struct AddressState {
        bool whitelisted;
        uint8 amountMinted;
    }

    MintingStep public mintingStep;
    uint public salePrice;
    string public hiddenBaseURI;

    mapping(address => AddressState) public addressState;
    mapping(uint => MintingStep) public tokenBaseURIType;
    mapping(MintingStep => string) public baseURI;

    constructor(string memory _tokenName, string memory _tokenSymbol, string memory _hiddenBaseURI) ERC721(_tokenName, _tokenSymbol) {
        hiddenBaseURI = _hiddenBaseURI;
        for(uint tokenId = 1; tokenId < 9; tokenId++){
            _mintWithBaseURIType(tokenId, msg.sender, MintingStep.Initial);
        }
    }
    
    modifier onlyOwnerOf(uint _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "The caller does not own token");
        _;
    }

    function mint(uint8 _quantity) external payable {
        require(mintingStep == MintingStep.Whitelist || mintingStep == MintingStep.Whitelist2 || mintingStep == MintingStep.WhitelistPresale || mintingStep == MintingStep.Public, "Contract state is not in minting state.");
        uint8 amountMintedOnSuccess = getAddressAmountMinted(msg.sender) + _quantity;
        if(mintingStep == MintingStep.Whitelist){
            require(isWhiteListed(msg.sender), "The caller is not whitelisted.");
            require(totalSupply() + uint(_quantity) <= POST_WHITELIST_SUPPLY, "Reached max supply at this stage");
            require(amountMintedOnSuccess <= WHITELIST_MAX_MINT, "Cannot mint more at this stage.");
        } else if(mintingStep == MintingStep.Whitelist2){
            require(isWhiteListed(msg.sender), "The caller is not whitelisted.");
            require(totalSupply() + uint(_quantity) <= POST_WHITELIST2_SUPPLY, "Reached max supply at this stage");
            require(amountMintedOnSuccess <= WHITELIST_MAX_MINT, "Cannot mint more at this stage.");
        } else if(mintingStep == MintingStep.WhitelistPresale){
            require(isWhiteListed(msg.sender), "The caller is not whitelisted.");
            require(totalSupply() + uint(_quantity) <= POST_WHITELIST_PRESALE_SUPPLY, "Reached max supply at this stage");
            require(amountMintedOnSuccess <= MAX_MINT, "Cannot mint more at this stage.");
        } else {
            require(totalSupply() + uint(_quantity) <= MAX_SUPPLY, "Reached max supply at this stage");
            require(amountMintedOnSuccess <= MAX_MINT, "Cannot mint more at this stage.");
        }
        require(msg.value >= salePrice * _quantity, "Not enough funds");
        _setAddressAmountMinted(msg.sender, amountMintedOnSuccess);
        uint totalSupply = totalSupply();
        for(uint i = 0; i<_quantity; i++){
            uint tokenId = totalSupply + i + 1;
            _mintWithBaseURIType(tokenId, msg.sender, mintingStep);
        }
    }

    function nextStep(uint _salePrice) public onlyOwner {
        uint totalSupply = totalSupply();
        setSalePrice(_salePrice);
        if(mintingStep == MintingStep.Initial){
            require(totalSupply == POST_INITIALIZE_SUPPLY, "Incorrect state: totalSupply != POST_INITIALIZE_SUPPLY");
            _teamMint(8, MintingStep.Whitelist);
            setMintingStep(MintingStep.Whitelist);
        } else if(mintingStep == MintingStep.Whitelist){
            require(totalSupply == POST_WHITELIST_SUPPLY, "Incorrect state: totalSupply != POST_WHITELIST_SUPPLY");
            _teamMint(80, MintingStep.Whitelist2);
            setMintingStep(MintingStep.Whitelist2);
        } else if(mintingStep == MintingStep.Whitelist2){
            require(totalSupply == POST_WHITELIST2_SUPPLY, "Incorrect state: totalSupply != POST_WHITELIST2_SUPPLY");
            _teamMint(400, MintingStep.WhitelistPresale);
            setMintingStep(MintingStep.WhitelistPresale);
        } else if(mintingStep == MintingStep.WhitelistPresale){
            require(totalSupply == POST_WHITELIST_PRESALE_SUPPLY, "Incorrect state: totalSupply != POST_WHITELIST_PRESALE_SUPPLY");
            _teamMint(256, MintingStep.Public);
            setMintingStep(MintingStep.Public);
        } else if(mintingStep == MintingStep.Public){
            setMintingStep(MintingStep.Rebirth);
        } else if(mintingStep == MintingStep.Rebirth){
            setMintingStep(MintingStep.Stable);
        }
    }

    function setMintingStep(MintingStep _mintingStep) public onlyOwner {
        mintingStep = _mintingStep;
    }
    
    function setSalePrice(uint _salePrice) public onlyOwner {
        salePrice = _salePrice * 1 ether;
    }

    function setBaseUri(string memory _baseURI, MintingStep _baseUriType) external onlyOwner {
        baseURI[_baseUriType] = _baseURI;
    }

    function setHiddenBaseUri(string memory _baseURI) external onlyOwner {
        hiddenBaseURI = _baseURI;
    }

    function send(address _account) external onlyOwner {
        (bool os, ) = payable(_account).call{value: address(this).balance}('');
        require(os);
    }

    function whitelist(address _account) external onlyOwner {
        require(!isWhiteListed(_account), "Account is already whitelisted");
        addressState[_account].whitelisted = true;
    }

    function rebirth(uint _tokenId) payable external onlyOwnerOf(_tokenId) {
        require(mintingStep == MintingStep.Rebirth, "Contract state is not in rebirth.");
        require(!hasBeenReborn(_tokenId), "NFT already reborn.");
        require(msg.value >= salePrice, "Not enough funds.");
        _setBaseUriType(_tokenId, MintingStep.Rebirth);
    }
    
    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "URI query for nonexistent token");
        string memory tokenBaseURI = bytes(baseURI[tokenBaseURIType[_tokenId]]).length == 0 ? hiddenBaseURI : baseURI[tokenBaseURIType[_tokenId]];
        return string(abi.encodePacked(tokenBaseURI, _tokenId.toString(), ".json"));
    }

    function hasBeenReborn(uint _tokenId) public view returns(bool) {
        return tokenBaseURIType[_tokenId] == MintingStep.Rebirth;
    }

    function getAddressAmountMinted(address _account) public view returns(uint8) {
        return addressState[_account].amountMinted;
    }

    function isWhiteListed(address _account) public view returns(bool) {
        return addressState[_account].whitelisted;
    }

    function teamMint(uint _quantity, MintingStep _baseURIType) external onlyOwner {
        require(totalSupply() + _quantity <= MAX_SUPPLY, "Exceeds max supply!");
        _teamMint(_quantity, _baseURIType);
    }

    function _teamMint(uint _quantity, MintingStep _baseURIType) internal {
        uint totalSupply = totalSupply();
        for(uint i = 0; i < _quantity; i++){
            uint tokenId = totalSupply + i + 1;
            _mintWithBaseURIType(tokenId, owner(), _baseURIType);
        }
    }

    function _mintWithBaseURIType(uint _tokenId, address _account, MintingStep _baseURIType) internal {
        _setBaseUriType(_tokenId, _baseURIType);
        _safeMint(_account, _tokenId);
    }

    function _setBaseUriType(uint _tokenId, MintingStep _baseUriType) internal {
        tokenBaseURIType[_tokenId] = _baseUriType;
    }

    function _setAddressAmountMinted(address _account, uint8 _amountMinted) internal {
        addressState[_account].amountMinted = _amountMinted;
    }

}