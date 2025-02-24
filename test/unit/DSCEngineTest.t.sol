// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    // Re-declare the event exactly as in DSCEngine
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /////////////////////////////////////////////
    // Constructor Tests                       //
    /////////////////////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////////////////////////////
    // Price Tests                             //
    /////////////////////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assert(expectedUsd == actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        // $2,000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /////////////////////////////////////////////
    // depositCollateral Tests                 //
    /////////////////////////////////////////////

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedTokens.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedTokenAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(expectedTokenAmount, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralEmitsEvent() public {
        vm.startPrank(USER);
        // Approve the DSCEngine to transfer the collateral on behalf of USER.
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Set the expectation for the CollateralDeposited event.
        // The parameters indicate that we expect to check the two indexed topics (USER and weth)
        // and the non-indexed data (AMOUNT_COLLATERAL).
        vm.expectEmit(true, true, false, true);
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);

        // Call the function under test.
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfTransferFromFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        vm.prank(owner);
        mockDsc.mint(USER, AMOUNT_COLLATERAL);

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        // Use IERC20 interface instead of ERC20Mock to approve
        IERC20(address(mockDsc)).approve(address(mockDsce), AMOUNT_COLLATERAL);
        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /////////////////////////////////////////////
    // redeemCollateral Tests                  //
    /////////////////////////////////////////////

    function testRedeemCollateralWorksProperly() public {
        // Arrange – User deposits collateral first.
        // Simulate the user by starting a prank.
        vm.startPrank(USER);

        // User approves the DSCEngine to spend their collateral.
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral – this transfers AMOUNT_COLLATERAL from USER to DSCEngine.
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Record DSCEngine's balance of weth and the user's balance after deposit.
        uint256 dsceBalanceBefore = ERC20Mock(weth).balanceOf(address(engine));
        uint256 userBalanceAfterDeposit = ERC20Mock(weth).balanceOf(USER);

        // Define the amount the user will redeem (e.g., half of the deposit).
        uint256 redeemAmount = 5 ether;

        // Set expectation for the CollateralRedeemed event.
        // The event parameters are:
        //   - redeemedFrom: USER
        //   - redeemedTo: USER
        //   - token: weth
        //   - amount: redeemAmount
        vm.expectEmit(true, true, true, true);
        emit CollateralRedeemed(USER, USER, weth, redeemAmount);

        // Act – User redeems part of their collateral.
        engine.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();

        // Assert – Check DSCEngine's token balance decreased by redeemAmount.
        uint256 dsceBalanceAfter = ERC20Mock(weth).balanceOf(address(engine));
        assertEq(dsceBalanceAfter, dsceBalanceBefore - redeemAmount, "DSCEngine balance incorrect after redeem");

        // Assert – Check the user's token balance increased by redeemAmount.
        uint256 userBalanceAfterRedeem = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalanceAfterRedeem, userBalanceAfterDeposit + redeemAmount, "User balance incorrect after redeem");
    }

    /////////////////////////////////////////////
    // mintDsc Tests                           //
    /////////////////////////////////////////////

    function testMintDscWorksProperly() public {
        // Arrange: Start acting as the USER.
        vm.startPrank(USER);

        // User must approve DSCEngine to transfer their collateral (weth).
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral into DSCEngine.
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Verify initial minted DSC is zero.
        (uint256 totalDscMinted,) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, 0, "Initial minted DSC should be zero");

        // Act: Mint DSC.
        uint256 mintAmount = 1 ether; // Mint an amount that keeps the health factor safe.
        engine.mintDsc(mintAmount);

        // Assert: Check that the DSCEngine's record has been updated.
        (totalDscMinted,) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, mintAmount, "Minted DSC record is incorrect");

        // Assert: Check that the DecentralizedStableCoin token balance increased accordingly.
        uint256 dscBalance = dsc.balanceOf(USER);
        assertEq(dscBalance, mintAmount, "User DSC token balance is incorrect");

        vm.stopPrank();
    }

    function testRevertsIfMintFails() public {
        // Arrange:
        // Create arrays for allowed tokens and corresponding price feeds.
        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = weth;
        address[] memory feedAddresses = new address[](1);
        feedAddresses[0] = ethUsdPriceFeed;

        // Deploy a mock DSC that always fails on mint.
        MockFailedMintDSC failingDsc = new MockFailedMintDSC();

        // Deploy a new DSCEngine instance that uses the failing DSC.
        DSCEngine engineWithFailingMint = new DSCEngine(tokenAddresses, feedAddresses, address(failingDsc));

        // Transfer ownership of the failing DSC to DSCEngine.
        // This makes DSCEngine authorized to call mint on the DSC.
        failingDsc.transferOwnership(address(engineWithFailingMint));

        // Deposit collateral so that the user's health factor is safe.
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engineWithFailingMint), AMOUNT_COLLATERAL);
        engineWithFailingMint.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Act & Assert:
        // DSCEngine calls mint on failingDsc, which returns false. DSCEngine should then revert with DSCEngine__MintFailed.
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        engineWithFailingMint.mintDsc(1 ether);
        vm.stopPrank();
    }

    /////////////////////////////////////////////
    // burnDsc Tests                           //
    /////////////////////////////////////////////

    function testBurnDscWorksProperly() public {
        // Arrange – Setup initial deposit and mint
        vm.startPrank(USER);

        // Approve DSCEngine to spend WETH
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral to allow minting DSC
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Mint DSC (assume 5 DSC is within safe limits)
        uint256 mintAmount = 5 ether;
        engine.mintDsc(mintAmount);

        // Verify that DSC was minted successfully
        (uint256 totalDscMintedBefore,) = engine.getAccountInformation(USER);
        assertEq(totalDscMintedBefore, mintAmount, "Minted DSC amount incorrect");

        uint256 userDscBalanceBefore = dsc.balanceOf(USER);
        assertEq(userDscBalanceBefore, mintAmount, "User DSC balance incorrect before burn");

        // Act – Burn DSC
        uint256 burnAmount = 3 ether;

        // 🔹 FIX: User must approve DSCEngine to transfer their DSC tokens before burning
        dsc.approve(address(engine), burnAmount);

        engine.burnDsc(burnAmount);

        // Assert – Check DSC amounts after burn
        (uint256 totalDscMintedAfter,) = engine.getAccountInformation(USER);
        assertEq(totalDscMintedAfter, mintAmount - burnAmount, "DSC minted amount incorrect after burn");

        uint256 userDscBalanceAfter = dsc.balanceOf(USER);
        assertEq(userDscBalanceAfter, userDscBalanceBefore - burnAmount, "User DSC balance incorrect after burn");

        // Ensure health factor remains valid after burning
        uint256 healthFactor = engine.getHealthFactor(USER);
        assertGt(healthFactor, 1e18, "Health factor should remain valid");

        vm.stopPrank();
    }
}
