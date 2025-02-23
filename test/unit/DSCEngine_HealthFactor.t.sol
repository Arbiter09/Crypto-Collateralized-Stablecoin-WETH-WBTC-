// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {console} from "forge-std/Script.sol";

contract DSCEngineHealthFactorTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 WETH
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether; // User starts with 100 WETH
    uint256 public constant DSC_TO_MINT = 5000e18; // 5000 DSC (assuming 1 DSC = $1)

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();

        // Mint mock WETH to user for testing
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////////////////////////////
    // Health Factor Tests                       //
    ///////////////////////////////////////////////

    /// @notice Test if health factor is > 1 after depositing sufficient collateral
    function testHealthFactorIsGreaterThanOneAfterDeposit() public {
        vm.startPrank(USER);

        // Approve & deposit collateral
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        engine.mintDsc(1e18);

        // Check health factor
        uint256 healthFactor = engine.getHealthFactor(USER);
        assert(healthFactor >= 1e18);

        vm.stopPrank();
    }

    /// @notice Test if user can mint DSC while keeping health factor above 1
    function testCanMintDSCIfHealthFactorIsAboveOne() public {
        vm.startPrank(USER);

        // Approve & deposit collateral
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Mint some DSC (should not break health factor)
        engine.mintDsc(DSC_TO_MINT);

        // Check health factor after minting
        uint256 healthFactor = engine.getHealthFactor(USER);
        assertGt(healthFactor, 1e18, "Health factor should still be greater than 1 after minting");

        vm.stopPrank();
    }

    /// @notice Test if health factor is below 1 when collateral value decreases
    function testHealthFactorDropsBelowOneIfCollateralLosesValue() public {
        vm.startPrank(USER);

        // Approve & deposit collateral
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Mint DSC close to max allowed (but still safe)
        engine.mintDsc(DSC_TO_MINT);

        // Simulate ETH price dropping (mocking Chainlink feed)
        uint256 newLowPrice = 500e8; // Reduce ETH/USD price to $500
        vm.mockCall(
            ethUsdPriceFeed, abi.encodeWithSignature("latestRoundData()"), abi.encode(0, int256(newLowPrice), 0, 0, 0)
        );

        // Check health factor (should now be below 1)
        uint256 healthFactor = engine.getHealthFactor(USER);
        assertLt(healthFactor, 1e18, "Health factor should be below 1 after price drop");

        vm.stopPrank();
    }
}
