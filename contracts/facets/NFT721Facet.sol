// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibDiamond.sol";

contract NFT721Facet {
    event Transfer(address indexed from, address indexed to, uint indexed id);

    function _mint(address to,uint tokenId) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(to != address(0), "to is zero address");
        require(ds._ownerOf[tokenId] == address(0), "token already exists");

        ds._balanceOf[to]++;
        ds._ownerOf[tokenId] = to;
        
        emit Transfer(address(0), to, tokenId);
    }

    // Standard ERC721 functions implementation
    function balanceOf(address owner) external view returns (uint balance) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(owner != address(0), "invalid address");
        return ds._balanceOf[owner];
    }

    function ownerOf(uint tokenId) public view returns (address owner) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        owner = ds._ownerOf[tokenId];
        // require(owner != address(0), "invalid address");
    }

    function approve(address to, uint tokenId) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address owner = ds._ownerOf[tokenId];
        require(msg.sender == owner || ds.isApprovedForAll[owner][msg.sender], "not authorized");
        ds._approvals[tokenId] = to;
    }

    function _isApprovedOrOwner(address owner, address spender, uint tokenId) internal view returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return (
            spender == owner ||
            ds.isApprovedForAll[owner][spender] ||
            spender == ds._approvals[tokenId]
        );
    }

    function getApproved(uint tokenId) external view returns (address operator) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds._ownerOf[tokenId] != address(0), "token doent exist");
        return ds._approvals[tokenId];
    }

    function transferFrom(
        address from,
        address to,
        uint tokenId
    ) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(from == ds._ownerOf[tokenId], "not from owner");
        require(to != address(0), "to address is zero address");
        require(_isApprovedOrOwner(from, msg.sender, tokenId), "not authorized");

        ds._balanceOf[from]--;
        ds._balanceOf[to]++;
        ds._ownerOf[tokenId] = to;

        delete ds._approvals[tokenId];

        emit Transfer(from, to, tokenId);
    }
}