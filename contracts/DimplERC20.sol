// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DimplERC20 is ERC20, ERC20Snapshot, Ownable {
    constructor() ERC20("Dimpl", "DMP") {
        _mint(msg.sender, 10e26); // initialSupply for investors and community
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function snapshot() public returns(uint256) {
        return _snapshot();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}