// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./NFT721Facet.sol";
import "./ERC20Facet.sol";
import "../libraries/LibDiamond.sol";

contract LendingFacet {
    constructor(address _erc20Facet) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.erc20Facet = ERC20Facet(_erc20Facet);
        LibDiamond.setDetails();
        // ds.owner = msg.sender;
        // ds.maxLoanAmount = 100;
        // ds.loanDuration = 1 weeks;
        // ds.applicationFee = 5;
    }


    event LoanDisbursed(address beneficiary, uint256 amount);
    event LoanPaidBack(address beneficiary, uint256 amount);

    function requestLoan(address tokenAddress, uint256 tokenId, uint256 amount) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.nft721Facet = NFT721Facet(tokenAddress);
        require(ds._ownerOf[tokenId] == msg.sender, "you do not own the token");
        require(amount < 100, "lending limit exceeded");
        require(ds.amountBorrowed[msg.sender] == 0, "pending unpaid loan");

        // nft721Facet.approve(address(this), tokenId);
        require(ds._approvals[tokenId] == address(this), "NFT approval not set");

        NFT721Facet(tokenAddress).transferFrom(msg.sender, address(this), tokenId);
        require(ds.nft721Facet.ownerOf(tokenId) == address(this), "transfer not successful");

        // send money minus application fee to borrower
        ds.amountBorrowed[msg.sender] = amount;
        ds.loanTime[msg.sender] = block.timestamp;
        ds.userTokenId[msg.sender] = tokenId;
        ds.erc20Facet.transfer(msg.sender, amount - ds.applicationFee);

        emit LoanDisbursed(msg.sender, amount);
    }

    function paybackLoan() external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 amtBorrowed = ds.amountBorrowed[msg.sender];
        require(ds.erc20Facet.balanceOfERC20(msg.sender) >= amtBorrowed, "insufficient balance");
        require(ds.erc20Facet.approveERC20(address(this), amtBorrowed), "Token approval not set");
        require(block.timestamp < ds.loanTime[msg.sender] + ds.loanDuration, "loan terms already defaulted");

        ds.erc20Facet.transferERC20From(msg.sender, address(this), amtBorrowed);
        ds.amountBorrowed[msg.sender] = 0; // Reset the borrowed amount after repayment
        ds.loanTime[msg.sender] = 0;

        // transfer NFT back to owner
        ds.nft721Facet.transferFrom(address(this), msg.sender, ds.userTokenId[msg.sender]);
        emit LoanPaidBack(msg.sender, amtBorrowed);
    }

    // function actionOnDefault() external {
    //     require(msg.sender != address(0), "Invalid caller");
    //     require(msg.sender == owner, "Unauthorized");
    //     require(block.timestamp > loanTime[msg.sender] + loanDuration, "loan duration not yet over");


    // }
}