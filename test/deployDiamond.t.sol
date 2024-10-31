// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/LendingFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/NFT721Facet.sol";

contract DiamondTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20Facet erc20Facet;
    NFT721Facet nftFacet;
    LendingFacet lendingFacet;

    address borrower = address(0x123);
    uint256 constant INITIAL_BALANCE = 1000 ether;
    uint256 constant LOAN_AMOUNT = 50;
    uint256 constant APPLICATION_FEE = 5;

    function setUp() public {
        // Deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20Facet = new ERC20Facet();
        nftFacet = new NFT721Facet();
        lendingFacet = new LendingFacet(address(erc20Facet));

        // Create diamond cut
        FacetCut[] memory cut = new FacetCut[](5);
        cut[0] = (FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        }));
        cut[1] = (FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        }));
        cut[2] = (FacetCut({
            facetAddress: address(erc20Facet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC20Facet")
        }));
        cut[3] = (FacetCut({
            facetAddress: address(nftFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("NFT721Facet")
        }));
        cut[4] = (FacetCut({
            facetAddress: address(lendingFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("LendingFacet")
        }));

        // Upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        // Setup initial state
        ERC20Facet(address(diamond)).mint(address(diamond), INITIAL_BALANCE);
        ERC20Facet(address(diamond)).mint(borrower, INITIAL_BALANCE);
    }

    function testRequestLoanOwnershipCheck() public {
        vm.startPrank(borrower);
        
        // Try to request loan for non-owned NFT
        uint256 tokenId = 1;
        NFT721Facet(address(diamond))._mint(address(this), tokenId); // Mint to different address
        
        vm.expectRevert("you do not own the token");
        LendingFacet(address(diamond)).requestLoan(address(nftFacet), tokenId, LOAN_AMOUNT);
        
        vm.stopPrank();
    }

    function testRequestLoanLimitCheck() public {
        vm.startPrank(borrower);
        
        // Mint NFT to borrower
        uint256 tokenId = 1;
        NFT721Facet(address(diamond))._mint(borrower, tokenId);
        
        // Set NFT approval
        NFT721Facet(address(diamond)).approve(address(diamond), tokenId);
        
        // Try to request loan above limit
        uint256 overLimitAmount = 150; // Max is 100
        vm.expectRevert();
        LendingFacet(address(diamond)).requestLoan(address(nftFacet), tokenId, overLimitAmount);
        
        vm.stopPrank();
    }

    function testSuccessfulLoanRequest() public {
        vm.startPrank(borrower);
        
        // Mint NFT to borrower
        uint256 tokenId = 1;
        NFT721Facet(address(diamond))._mint(borrower, tokenId);
        
        // Set NFT approval
        NFT721Facet(address(diamond)).approve(address(diamond), tokenId);
        
        // Request loan
        LendingFacet(address(diamond)).requestLoan(address(nftFacet), tokenId, LOAN_AMOUNT);
        
        // Verify loan was processed
        assertEq(NFT721Facet(address(diamond)).ownerOf(tokenId), address(diamond), "NFT should be transferred to contract");
        assertEq(
            ERC20Facet(address(diamond)).balanceOfERC20(borrower),
            INITIAL_BALANCE + LOAN_AMOUNT - APPLICATION_FEE,
            "Incorrect loan amount received"
        );
        
        vm.stopPrank();
    }

    function testPaybackLoan() public {
        vm.startPrank(borrower);
        
        // Setup: Request a loan first
        uint256 tokenId = 1;
        NFT721Facet(address(diamond))._mint(borrower, tokenId);
        NFT721Facet(address(diamond)).approve(address(diamond), tokenId);
        LendingFacet(address(diamond)).requestLoan(address(nftFacet), tokenId, LOAN_AMOUNT);
        
        // Approve ERC20 tokens for payback
        ERC20Facet(address(diamond)).approveERC20(address(diamond), LOAN_AMOUNT);
        
        // Payback loan
        LendingFacet(address(diamond)).paybackLoan();
        
        // Verify loan was paid back
        assertEq(NFT721Facet(address(diamond)).ownerOf(tokenId), borrower, "NFT should be returned to borrower");
        assertEq(
            ERC20Facet(address(diamond)).balanceOfERC20(borrower),
            INITIAL_BALANCE - APPLICATION_FEE,
            "Incorrect balance after payback"
        );
        
        vm.stopPrank();
    }

    function testPreventMultipleLoans() public {
        vm.startPrank(borrower);
        
        // Setup: Take first loan
        uint256 tokenId1 = 1;
        NFT721Facet(address(diamond))._mint(borrower, tokenId1);
        NFT721Facet(address(diamond)).approve(address(diamond), tokenId1);
        LendingFacet(address(diamond)).requestLoan(address(nftFacet), tokenId1, LOAN_AMOUNT);
        
        // Try to take second loan
        uint256 tokenId2 = 2;
        NFT721Facet(address(diamond))._mint(borrower, tokenId2);
        NFT721Facet(address(diamond)).approve(address(diamond), tokenId2);
        
        vm.expectRevert("pending unpaid loan");
        LendingFacet(address(diamond)).requestLoan(address(nftFacet), tokenId2, LOAN_AMOUNT);
        
        vm.stopPrank();
    }

    function testLoanDefaultPreventsPayback() public {
        vm.startPrank(borrower);
        
        // Setup: Take a loan
        uint256 tokenId = 1;
        NFT721Facet(address(diamond))._mint(borrower, tokenId);
        NFT721Facet(address(diamond)).approve(address(diamond), tokenId);
        LendingFacet(address(diamond)).requestLoan(address(nftFacet), tokenId, LOAN_AMOUNT);
        
        // Move time forward past loan duration (1 week)
        vm.warp(block.timestamp + 1 weeks + 1);
        
        // Try to pay back after default
        ERC20Facet(address(diamond)).approveERC20(address(diamond), LOAN_AMOUNT);
        vm.expectRevert("loan terms already defaulted");
        LendingFacet(address(diamond)).paybackLoan();
        
        vm.stopPrank();
    }

    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}