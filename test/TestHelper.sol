// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/TMFactory.sol";
import "../src/Router.sol";
import "../src/TMMarket.sol";
import "../src/templates/TMERC20.sol";
import "./mocks/WNative.sol";
import "./mocks/TransferTaxToken.sol";

contract TestHelper is Test {
    ITMFactory public factory;
    Router public router;
    WNative public wnative;

    TMERC20 public basicToken;

    address public token0;
    address public token1;
    address public token2;

    address public market0w;
    address public market10;
    address public market21;

    uint256[] public askPrices0w;
    uint256[] public bidPrices0w;

    address public stakingAddress;

    function setUp() public virtual {
        wnative = new WNative();

        address factoryImp = address(new TMFactory(stakingAddress, address(wnative)));
        factory = ITMFactory(
            address(
                new TransparentUpgradeableProxy(
                    factoryImp,
                    address(this),
                    abi.encodeCall(TMFactory.initialize, (0.2e4, 0.5e4, address(this), address(this)))
                )
            )
        );

        router = new Router(address(0), address(0), address(0), address(0), address(factory), address(wnative));

        basicToken = new TMERC20(address(factory));

        factory.updateTokenImplementation(1, address(basicToken));

        vm.label(address(factory), "TMFactory");
        vm.label(address(router), "Router");
        vm.label(address(wnative), "WNative");
        vm.label(address(basicToken), "TMERC20 Implementation");
    }

    function setUpTokens() public {
        factory.addQuoteToken(address(wnative));

        askPrices0w.push(0e18);
        askPrices0w.push(10e18);
        askPrices0w.push(100e18);

        bidPrices0w.push(askPrices0w[0] * 80 / 100);
        bidPrices0w.push(askPrices0w[1] * 90 / 100);
        bidPrices0w.push(askPrices0w[2] * 95 / 100);

        ITMFactory.MarketCreationParameters memory params = ITMFactory.MarketCreationParameters(
            1, "Token0", "T0", address(wnative), 500_000_000e18, 0.2e4, 0.6e4, bidPrices0w, askPrices0w, abi.encode(18)
        );

        (token0, market0w) = factory.createMarketAndToken(params);

        factory.addQuoteToken(address(token0));

        uint256[] memory askPrices = new uint256[](3);
        askPrices[0] = 0.1e18;
        askPrices[1] = 0.5e18;
        askPrices[2] = 0.9e18;

        uint256[] memory bidPrices = new uint256[](3);
        bidPrices[0] = askPrices[0];
        bidPrices[1] = askPrices[1] * 90 / 100;
        bidPrices[2] = askPrices[2];

        params = ITMFactory.MarketCreationParameters(
            1, "Token1", "T1", address(token0), 100_000_000e18, 0.2e4, 0.6e4, bidPrices, askPrices, abi.encode(18)
        );

        (token1, market10) = factory.createMarketAndToken(params);

        factory.addQuoteToken(address(token1));

        askPrices[0] = 10e18;
        askPrices[1] = 20e18;
        askPrices[2] = 21e18;

        bidPrices[0] = 1e18;
        bidPrices[1] = 10e18;
        bidPrices[2] = 20e18;

        params = ITMFactory.MarketCreationParameters(
            1, "Token2", "T2", address(token1), 50_000_000e18, 0.2e4, 0.6e4, bidPrices, askPrices, abi.encode(18)
        );

        (token2, market21) = factory.createMarketAndToken(params);

        vm.label(token0, "Token0");
        vm.label(token1, "Token1");
        vm.label(token2, "Token2");

        vm.label(market0w, "Market0W");
        vm.label(market10, "Market10");
        vm.label(market21, "Market21");
    }

    function _createTaxTokenMarket() internal returns (address taxToken, address market) {
        uint256[] memory prices = new uint256[](2);

        prices[0] = 1e18;
        prices[1] = 1e18 + 1;

        factory.updateTokenImplementation(2, address(new TransferTaxToken(address(factory), 0.1e18)));

        ITMFactory.MarketCreationParameters memory params = ITMFactory.MarketCreationParameters(
            2, "TaxToken", "TT", address(wnative), 500_000_000e18, 0.2e4, 0.6e4, prices, prices, new bytes(0)
        );

        (taxToken, market) = factory.createMarketAndToken(params);
    }

    function _predictContractAddress(uint256 deltaNonce) internal view returns (address) {
        uint256 nonce = vm.getNonce(address(this)) + deltaNonce;
        return vm.computeCreateAddress(address(this), nonce);
    }
}
