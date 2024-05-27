// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/TMFactory.sol";
import "../src/Router.sol";
import "../src/TMMarket.sol";
import "../src/templates/BasicERC20.sol";
import "./mocks/WNative.sol";

contract TestHelper is Test {
    TMFactory public factory;
    Router public router;
    WNative public wnative;

    BasicERC20 public basicToken;

    address public token0;
    address public token1;
    address public token2;

    address public market0w;
    address public market10;
    address public market21;

    function setUp() public virtual {
        wnative = new WNative();

        factory = new TMFactory(0.1e18, address(this));
        router = new Router(address(0), address(0), address(0), address(0), address(factory), address(wnative));

        basicToken = new BasicERC20();

        factory.updateTokenImplementation(ITMFactory.TokenType.BasicERC20, address(basicToken));

        vm.label(address(factory), "TMFactory");
        vm.label(address(router), "Router");
        vm.label(address(wnative), "WNative");
        vm.label(address(basicToken), "BasicERC20 Implementation");
    }

    function setUpTokens() public {
        factory.addQuoteToken(address(wnative));

        uint256[] memory askPrices = new uint256[](3);
        askPrices[0] = 0e18;
        askPrices[1] = 10e18;
        askPrices[2] = 100e18;

        uint256[] memory bidPrices = new uint256[](3);
        bidPrices[0] = askPrices[0] * 80 / 100;
        bidPrices[1] = askPrices[1] * 90 / 100;
        bidPrices[2] = askPrices[2] * 95 / 100;

        (token0, market0w) = factory.createMarketAndToken(
            ITMFactory.TokenType.BasicERC20, "Token0", "T0", address(wnative), 500_000_000e18, bidPrices, askPrices
        );

        factory.addQuoteToken(address(token0));

        askPrices[0] = 0.1e18;
        askPrices[1] = 0.5e18;
        askPrices[2] = 0.9e18;

        bidPrices[0] = askPrices[0];
        bidPrices[1] = askPrices[1] * 90 / 100;
        bidPrices[2] = askPrices[2];

        (token1, market10) = factory.createMarketAndToken(
            ITMFactory.TokenType.BasicERC20, "Token1", "T1", address(token0), 100_000_000e18, bidPrices, askPrices
        );

        factory.addQuoteToken(address(token1));

        askPrices[0] = 10e18;
        askPrices[1] = 20e18;
        askPrices[2] = 21e18;

        bidPrices[0] = 1e18;
        bidPrices[1] = 10e18;
        bidPrices[2] = 20e18;

        (token2, market21) = factory.createMarketAndToken(
            ITMFactory.TokenType.BasicERC20, "Token2", "T2", address(token1), 50_000_000e18, bidPrices, askPrices
        );

        vm.label(token0, "Token0");
        vm.label(token1, "Token1");
        vm.label(token2, "Token2");

        vm.label(market0w, "Market0W");
        vm.label(market10, "Market10");
        vm.label(market21, "Market21");
    }
}
