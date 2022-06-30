// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Webe is Ownable, ERC721Enumerable {
    using Strings for uint;

    uint public constant MAX_SUPPLY = 8888;
    uint public constant POST_TEAM_SUPPLY = 1640;
    uint public constant POST_WHITELIST2_SUPPLY = 888;
    uint public constant POST_WHITELIST_SUPPLY = 88;
    uint public constant POST_FIRST8_SUPPLY = 8;
    uint public constant MAX_MINT = 5;
    uint public constant WHITELIST_MAX_MINT = 1;
    
    enum MintingStep {
        Initial,
        WhitelistMint,
        Whitelist2Mint,
        TeamMint,
        PublicMint,
        Rebirth,
        Stable
    }
    enum BaseURIType {
        Default,
        First8,
        Whitelist,
        Whitelist2,
        Team,
        Rebirth
    }

    struct AddressState {
        bool whitelisted;
        uint8 amountMinted;
    }

    MintingStep public mintingStep;
    uint public salePrice;
    string public hiddenBaseURI;

    mapping(address => AddressState) public addressState;
    mapping(uint => BaseURIType) public tokenBaseURIType;
    mapping(BaseURIType => string) public baseURI;

    constructor(string memory _hiddenBaseURI) ERC721("WEBE", "WBE") {
        hiddenBaseURI = _hiddenBaseURI;
        _mintFirst8OnDeploy();
    }
    
    modifier onlyOwnerOf(uint _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "The caller does not own token");
        _;
    }

    function mint(uint8 _quantity) external payable {
        require(mintingStep == MintingStep.PublicMint || mintingStep == MintingStep.WhitelistMint || mintingStep == MintingStep.Whitelist2Mint, "Contract state is not in minting state.");
        uint8 amountMintedOnSuccess = getAddressAmountMinted(msg.sender) + _quantity;
        if(mintingStep == MintingStep.WhitelistMint){
            require(_isWhiteListed(msg.sender), "The caller is not whitelisted.");
            require(totalSupply() + uint(_quantity) <= POST_WHITELIST_SUPPLY, "Reached max Supply");
            require(amountMintedOnSuccess <= WHITELIST_MAX_MINT, "Cannot mint more at this stage.");
        } else if(mintingStep == MintingStep.Whitelist2Mint){
            require(_isWhiteListed(msg.sender), "The caller is not whitelisted.");
            require(totalSupply() + uint(_quantity) <= POST_WHITELIST2_SUPPLY, "Reached max Supply");
            require(amountMintedOnSuccess <= WHITELIST_MAX_MINT, "Cannot mint more at this stage.");
        } else {
            require(totalSupply() + uint(_quantity) <= MAX_SUPPLY, "Reached max Supply");
            require(amountMintedOnSuccess <= MAX_MINT, "Cannot mint more at this stage.");
        }
        require(msg.value >= salePrice * _quantity, "Not enough funds");
        _setAddressAmountMinted(msg.sender, amountMintedOnSuccess);
        uint totalSupply = totalSupply();
        for(uint i = 0; i<_quantity; i++){
            uint tokenId = totalSupply + i + 1;
            if(mintingStep == MintingStep.WhitelistMint) _setBaseUriType(tokenId, BaseURIType.Whitelist);
            if(mintingStep == MintingStep.Whitelist2Mint) _setBaseUriType(tokenId, BaseURIType.Whitelist2);
            _safeMint(msg.sender, tokenId);
        }
    }

    function teamMint(uint8 _quantity, address _account) external onlyOwner {
        require(mintingStep == MintingStep.TeamMint, "Contract state is not in team minting state.");
        require(totalSupply() + uint(_quantity) <= POST_TEAM_SUPPLY, "Reached max Supply");
        uint totalSupply = totalSupply();
        for(uint i = 0; i<_quantity; i++){
            uint tokenId = totalSupply + i + 1;
            _setBaseUriType(tokenId, BaseURIType.Team);
            _safeMint(_account, tokenId);
        }
    }

    function setMintingStep(MintingStep _mintingStep) external onlyOwner {
        mintingStep = _mintingStep;
    }

    function setBaseUri(string memory _baseURI, BaseURIType _baseUriType) external onlyOwner {
        baseURI[_baseUriType] = _baseURI;
    }

    function setSalePrice(uint _salePrice) external onlyOwner {
        salePrice = _salePrice;
    }

    function send(address _account) external onlyOwner {
        (bool os, ) = payable(_account).call{value: address(this).balance}('');
        require(os);
    }

    function whitelist(address _invitedAccount) external onlyOwner {
        require(_isWhiteListed(_invitedAccount), "Account is already whitelisted");
        addressState[_invitedAccount].whitelisted = true;
    }

    function rebirth(uint _tokenId) payable external onlyOwnerOf(_tokenId) {
        require(mintingStep == MintingStep.Rebirth, "Contract state is not in rebirth.");
        require(!hasBeenReborn(_tokenId), "NFT already reborn.");
        require(msg.value >= salePrice, "Not enough funds.");
        _setBaseUriType(_tokenId, BaseURIType.Rebirth);
    }
    
    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "URI query for nonexistent token");
        string memory tokenBaseURI = bytes(baseURI[tokenBaseURIType[_tokenId]]).length == 0 ? hiddenBaseURI : baseURI[tokenBaseURIType[_tokenId]];
        return string(abi.encodePacked(tokenBaseURI, _tokenId.toString(), ".json"));
    }

    function hasBeenReborn(uint _tokenId) public view returns(bool) {
        return tokenBaseURIType[_tokenId] == BaseURIType.Rebirth;
    }

    function getAddressAmountMinted(address _account) public view returns(uint8) {
        return addressState[_account].amountMinted;
    }

    function _mintFirst8OnDeploy() internal {
        uint totalSupply = totalSupply();
        for(uint i = 0; i < POST_FIRST8_SUPPLY; i++){
            uint tokenId = totalSupply + i + 1;
            _setBaseUriType(tokenId, BaseURIType.First8);
            _safeMint(owner(), tokenId);
        }
    }

    function _setBaseUriType(uint _tokenId, BaseURIType _baseUriType) internal {
        tokenBaseURIType[_tokenId] = _baseUriType;
    }

    function _isWhiteListed(address _account) internal view returns(bool) {
        return addressState[_account].whitelisted;
    }
    function _setAddressAmountMinted(address _account, uint8 _amountMinted) internal {
        addressState[_account].amountMinted = _amountMinted;
    }

}