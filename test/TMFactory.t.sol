// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract TMFactoryTest is Test {
    TMFactory factory;
    address wnative;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    address feeRecipient = makeAddr("FeeRecipient");

    function setUp() public {
        wnative = address(new WNative());

        address factoryImp = address(new TMFactory());
        factory = TMFactory(
            address(
                new TransparentUpgradeableProxy(
                    factoryImp, address(this), abi.encodeCall(TMFactory.initialize, (0.1e18, address(this)))
                )
            )
        );
    }

    function test_Constructor() public view {
        assertEq(factory.owner(), address(this), "test_Constructor::1");
        assertEq(factory.getProtocolShare(), 0.1e18, "test_Constructor::2");
    }

    function test_Fuzz_UpdateTokenImplementation(address implementation, uint96 tokenType) public {
        tokenType = uint96(bound(tokenType, 1, type(uint96).max));

        assertEq(factory.getTokenImplementation(tokenType), address(0), "test_Fuzz_UpdateTokenImplementation::1");
        assertEq(factory.getTokenImplementation(tokenType - 1), address(0), "test_Fuzz_UpdateTokenImplementation::2");

        factory.updateTokenImplementation(tokenType, implementation);

        assertEq(factory.getTokenImplementation(tokenType), implementation, "test_Fuzz_UpdateTokenImplementation::3");
        assertEq(factory.getTokenImplementation(tokenType - 1), address(0), "test_Fuzz_UpdateTokenImplementation::4");

        factory.updateTokenImplementation(tokenType, address(0));

        assertEq(factory.getTokenImplementation(tokenType), address(0), "test_Fuzz_UpdateTokenImplementation::5");
        assertEq(factory.getTokenImplementation(tokenType - 1), address(0), "test_Fuzz_UpdateTokenImplementation::6");
    }

    function test_Revert_UpdateTokenImplementation() public {
        vm.expectRevert(ITMFactory.TMFactory__InvalidTokenType.selector);
        factory.updateTokenImplementation(0, address(0));
    }

    function test_Fuzz_AddQuoteToken(address token) public {
        address[] memory quoteTokens = factory.getQuoteTokens();
        assertEq(quoteTokens.length, 0, "test_Fuzz_AddQuoteToken::1");

        assertFalse(factory.isQuoteToken(token), "test_Fuzz_AddQuoteToken::2");

        factory.addQuoteToken(token);

        quoteTokens = factory.getQuoteTokens();
        assertEq(quoteTokens.length, 1, "test_Fuzz_AddQuoteToken::3");
        assertEq(quoteTokens[0], token, "test_Fuzz_AddQuoteToken::4");
        assertTrue(factory.isQuoteToken(token), "test_Fuzz_AddQuoteToken::5");

        vm.expectRevert(ITMFactory.TMFactory__QuoteTokenAlreadyAdded.selector);
        factory.addQuoteToken(token);
    }

    function test_Revert_AddQuoteToken() public {
        for (uint160 i; i < 64; ++i) {
            factory.addQuoteToken(address(i));
        }

        vm.expectRevert(ITMFactory.TMFactory__MaxQuoteTokensExceeded.selector);
        factory.addQuoteToken(address(uint160(64)));
    }

    function test_Fuzz_RemoveQuoteToken(address token1, address token2) public {
        unchecked {
            token2 = token1 == token2 ? address(uint160(token1) + 1) : token2;
        }

        factory.addQuoteToken(token1);
        factory.addQuoteToken(token2);

        address[] memory quoteTokens = factory.getQuoteTokens();
        assertEq(quoteTokens.length, 2, "test_Fuzz_RemoveQuoteToken::1");
        assertEq(quoteTokens[0], token1, "test_Fuzz_RemoveQuoteToken::2");
        assertEq(quoteTokens[1], token2, "test_Fuzz_RemoveQuoteToken::3");
        assertTrue(factory.isQuoteToken(token1), "test_Fuzz_RemoveQuoteToken::4");
        assertTrue(factory.isQuoteToken(token2), "test_Fuzz_RemoveQuoteToken::5");

        factory.removeQuoteToken(token2);

        quoteTokens = factory.getQuoteTokens();

        assertEq(quoteTokens.length, 1, "test_Fuzz_RemoveQuoteToken::6");
        assertEq(quoteTokens[0], token1, "test_Fuzz_RemoveQuoteToken::7");
        assertTrue(factory.isQuoteToken(token1), "test_Fuzz_RemoveQuoteToken::8");
        assertFalse(factory.isQuoteToken(token2), "test_Fuzz_RemoveQuoteToken::9");

        factory.removeQuoteToken(token1);

        quoteTokens = factory.getQuoteTokens();

        assertEq(quoteTokens.length, 0, "test_Fuzz_RemoveQuoteToken::10");
        assertFalse(factory.isQuoteToken(token1), "test_Fuzz_RemoveQuoteToken::11");
        assertFalse(factory.isQuoteToken(token2), "test_Fuzz_RemoveQuoteToken::12");

        vm.expectRevert(ITMFactory.TMFactory__QuoteTokenNotFound.selector);
        factory.removeQuoteToken(token1);

        vm.expectRevert(ITMFactory.TMFactory__QuoteTokenNotFound.selector);
        factory.removeQuoteToken(token2);

        factory.addQuoteToken(token2);

        vm.expectRevert(ITMFactory.TMFactory__QuoteTokenNotFound.selector);
        factory.removeQuoteToken(token1);

        quoteTokens = factory.getQuoteTokens();

        assertEq(quoteTokens.length, 1, "test_Fuzz_RemoveQuoteToken::13");
        assertEq(quoteTokens[0], token2, "test_Fuzz_RemoveQuoteToken::14");
        assertFalse(factory.isQuoteToken(token1), "test_Fuzz_RemoveQuoteToken::15");
        assertTrue(factory.isQuoteToken(token2), "test_Fuzz_RemoveQuoteToken::16");
    }

    function test_Fuzz_UpdateProtocolShare(uint64 shares) public {
        shares = uint64(bound(shares, 0, 1e18));

        assertEq(factory.getProtocolShare(), 0.1e18, "test_Fuzz_UpdateProtocolShare::1");

        factory.updateProtocolShare(shares);

        assertEq(factory.getProtocolShare(), shares, "test_Fuzz_UpdateProtocolShare::2");

        factory.updateProtocolShare(0);

        assertEq(factory.getProtocolShare(), 0, "test_Fuzz_UpdateProtocolShare::3");

        factory.updateProtocolShare(1e18);

        assertEq(factory.getProtocolShare(), 1e18, "test_Fuzz_UpdateProtocolShare::4");

        vm.expectRevert(ITMFactory.TMFactory__InvalidProtocolShare.selector);
        factory.updateProtocolShare(uint64(bound(shares, 1e18 + 1, type(uint64).max)));
    }

    function test_Fuzz_UpdateProtocolFeeRecipient(address recipient) public {
        assertEq(factory.getProtocolFeeRecipient(), address(0), "test_Fuzz_UpdateProtocolFeeRecipient::1");

        factory.updateProtocolFeeRecipient(recipient);

        assertEq(factory.getProtocolFeeRecipient(), recipient, "test_Fuzz_UpdateProtocolFeeRecipient::2");

        factory.updateProtocolFeeRecipient(address(0));

        assertEq(factory.getProtocolFeeRecipient(), address(0), "test_Fuzz_UpdateProtocolFeeRecipient::3");
    }

    function test_Fuzz_CreateTokenAndMarket(
        address sender,
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 amount
    ) public {
        decimals = uint8(bound(decimals, 0, 18));

        BasicERC20 implementation = new BasicERC20(address(factory));
        factory.updateTokenImplementation(1, address(implementation));
        factory.addQuoteToken(wnative);

        uint256[] memory prices = new uint256[](2);
        prices[0] = 0;
        prices[1] = 1e18;

        amount = bound(amount, 10 ** decimals, uint256(type(uint128).max) * 10 ** decimals / 1e18);

        vm.prank(sender);
        (address token, address market) =
            factory.createMarketAndToken(1, name, symbol, wnative, amount, prices, prices, abi.encode(decimals));

        assertEq(factory.getCreatorOf(market), sender, "test_Fuzz_CreateTokenAndMarket::1");
        assertEq(factory.getProtocolShareOf(market), 0.1e18, "test_Fuzz_CreateTokenAndMarket::2");
        assertEq(factory.getTokenType(token), 1, "test_Fuzz_CreateTokenAndMarket::3");
        assertEq(factory.getMarketOf(token), market, "test_Fuzz_CreateTokenAndMarket::4");

        (bool tokenAisBase, address market_) = factory.getMarket(token, wnative);

        assertEq(tokenAisBase, true, "test_Fuzz_CreateTokenAndMarket::5");
        assertEq(market_, market, "test_Fuzz_CreateTokenAndMarket::6");

        (tokenAisBase, market_) = factory.getMarket(wnative, token);

        assertEq(tokenAisBase, false, "test_Fuzz_CreateTokenAndMarket::7");
        assertEq(market_, market, "test_Fuzz_CreateTokenAndMarket::8");

        assertEq(factory.getMarketsLength(), 1, "test_Fuzz_CreateTokenAndMarket::9");
        assertEq(factory.getMarketAt(0), market, "test_Fuzz_CreateTokenAndMarket::10");
    }

    function test_Fuzz_Revert_CreateTokenAndMarket(address token, uint96 tokenType) public {
        token = address(uint160(bound(uint160(token), 0x0a, type(uint160).max)));
        tokenType = uint96(bound(tokenType, 1, type(uint96).max));

        vm.expectRevert(ITMFactory.TMFactory__InvalidTokenType.selector);
        factory.createMarketAndToken(tokenType, "", "", address(0), 0, new uint256[](2), new uint256[](2), new bytes(0));

        address badToken = address(new BadERC20(address(factory)));

        factory.updateTokenImplementation(tokenType, badToken);

        uint256[] memory prices = new uint256[](2);
        prices[0] = 0;
        prices[1] = 1e18;

        vm.expectRevert(ITMFactory.TMFactory__InvalidQuoteToken.selector);
        factory.createMarketAndToken(tokenType, "", "", token, 0, prices, prices, new bytes(0));

        factory.addQuoteToken(token);
        vm.etch(token, badToken.code);

        vm.expectRevert(ITMFactory.TMFactory__InvalidBalance.selector);
        factory.createMarketAndToken(tokenType, "", "", token, 1e18, prices, prices, new bytes(0));
    }

    function test_Fuzz_UpdateCreator(address sender, address other) public {
        if (sender == other) {
            unchecked {
                other = address(uint160(sender) + 1);
            }
        }

        (, address market) = _setUpAndCreateToken(sender);

        assertEq(factory.getCreatorOf(market), sender, "test_Fuzz_UpdateCreator::1");

        vm.prank(sender);
        factory.updateCreator(market, other);

        assertEq(factory.getCreatorOf(market), other, "test_Fuzz_UpdateCreator::2");

        vm.expectRevert(ITMFactory.TMFactory__InvalidCaller.selector);
        vm.prank(sender);
        factory.updateCreator(market, sender);

        vm.prank(other);
        factory.updateCreator(market, sender);

        assertEq(factory.getCreatorOf(market), sender, "test_Fuzz_UpdateCreator::3");
    }

    function test_Fuzz_UpdateProtocolShareOf(uint64 shares) public {
        shares = uint64(bound(shares, 0, 1e18));

        (, address market1) = _setUpAndCreateToken(alice);
        (, address market2) = _setUpAndCreateToken(bob);

        assertEq(factory.getProtocolShareOf(market1), 0.1e18, "test_Fuzz_UpdateProtocolShareOf::1");
        assertEq(factory.getProtocolShareOf(market2), 0.1e18, "test_Fuzz_UpdateProtocolShareOf::2");

        factory.updateProtocolShareOf(market1, shares);

        assertEq(factory.getProtocolShareOf(market1), shares, "test_Fuzz_UpdateProtocolShareOf::3");
        assertEq(factory.getProtocolShareOf(market2), 0.1e18, "test_Fuzz_UpdateProtocolShareOf::4");

        factory.updateProtocolShareOf(market1, 0);
        factory.updateProtocolShareOf(market2, shares);

        assertEq(factory.getProtocolShareOf(market1), 0, "test_Fuzz_UpdateProtocolShareOf::5");
        assertEq(factory.getProtocolShareOf(market2), shares, "test_Fuzz_UpdateProtocolShareOf::6");

        vm.expectRevert(ITMFactory.TMFactory__InvalidProtocolShare.selector);
        factory.updateProtocolShareOf(market1, uint64(bound(shares, 1e18 + 1, type(uint64).max)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        factory.updateProtocolShareOf(market1, 1e18);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.prank(bob);
        factory.updateProtocolShareOf(market1, 1e18);
    }

    function test_ClaimFees() public {
        (address token1, address market1) = _setUpAndCreateToken(alice, 0.5e18);

        Router router = new Router(address(0), address(0), address(0), address(0), address(factory), address(wnative));

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token1);

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0);

        (uint256 protocol1, uint256 creator1) = ITMMarket(market1).getPendingFees();

        factory.updateProtocolFeeRecipient(feeRecipient);

        vm.prank(alice);
        uint256 claimed1c = factory.claimFees(market1, alice);

        assertEq(claimed1c, creator1, "test_ClaimFees::1");
        assertEq(IERC20(wnative).balanceOf(alice), creator1, "test_ClaimFees::2");

        {
            (uint256 protocol1_, uint256 creator1_) = ITMMarket(market1).getPendingFees();

            assertEq(protocol1_, protocol1, "test_ClaimFees::3");
            assertEq(creator1_, 0, "test_ClaimFees::4");

            vm.prank(address(feeRecipient));
            uint256 claimed1p = factory.claimFees(market1, feeRecipient);

            assertEq(claimed1p, protocol1, "test_ClaimFees::5");
            assertEq(IERC20(wnative).balanceOf(feeRecipient), protocol1, "test_ClaimFees::6");

            (protocol1_, creator1_) = ITMMarket(market1).getPendingFees();

            assertEq(protocol1_, 0, "test_ClaimFees::7");
            assertEq(creator1_, 0, "test_ClaimFees::8");
        }

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0);

        (uint256 protocol2, uint256 creator2) = ITMMarket(market1).getPendingFees();

        assertApproxEqAbs(protocol2, protocol1, 1, "test_ClaimFees::9");
        assertApproxEqAbs(creator2, creator1, 1, "test_ClaimFees::10");

        vm.prank(feeRecipient);
        uint256 claimed2p = factory.claimFees(market1, feeRecipient);

        assertEq(claimed2p, protocol2, "test_ClaimFees::11");
        assertEq(IERC20(wnative).balanceOf(feeRecipient), protocol1 + protocol2, "test_ClaimFees::12");

        (uint256 protocol2_, uint256 creator2_) = ITMMarket(market1).getPendingFees();

        assertEq(protocol2_, 0, "test_ClaimFees::13");
        assertEq(creator2_, creator2, "test_ClaimFees::14");

        vm.prank(alice);
        uint256 claimed2c = factory.claimFees(market1, alice);

        assertEq(claimed2c, creator2, "test_ClaimFees::15");
        assertEq(IERC20(wnative).balanceOf(alice), creator1 + creator2, "test_ClaimFees::16");

        (protocol2_, creator2_) = ITMMarket(market1).getPendingFees();

        assertEq(protocol2_, 0, "test_ClaimFees::17");
        assertEq(creator2_, 0, "test_ClaimFees::18");
    }

    function test_ClaimFeesAndUpdateProtocolFees() public {
        (address token1, address market1) = _setUpAndCreateToken(alice, 0.5e18);

        Router router = new Router(address(0), address(0), address(0), address(0), address(factory), address(wnative));

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token1);

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0);

        (uint256 protocol1, uint256 creator1) = ITMMarket(market1).getPendingFees();

        assertGt(protocol1, 0, "test_ClaimFeesAndUpdateProtocolFees::1");
        assertGt(creator1, 0, "test_ClaimFeesAndUpdateProtocolFees::2");

        factory.updateProtocolShareOf(market1, 0.5e18);

        (uint256 protocol1_, uint256 creator1_) = ITMMarket(market1).getPendingFees();

        assertEq(protocol1_, protocol1, "test_ClaimFeesAndUpdateProtocolFees::3");
        assertEq(creator1_, creator1, "test_ClaimFeesAndUpdateProtocolFees::4");
    }

    function test_Revert_ClaimFees() public {
        (, address market1) = _setUpAndCreateToken(alice);
        (, address market2) = _setUpAndCreateToken(bob);

        vm.expectRevert(ITMFactory.TMFactory__InvalidRecipient.selector);
        factory.claimFees(market1, address(0));

        vm.expectRevert(ITMFactory.TMFactory__InvalidCaller.selector);
        vm.prank(alice);
        factory.claimFees(market2, alice);
    }

    function _setUpAndCreateToken(address sender) internal returns (address token, address market) {
        return _setUpAndCreateToken(sender, 1e18);
    }

    function _setUpAndCreateToken(address sender, uint256 ratio) internal returns (address token, address market) {
        require(ratio <= 1e18, "Ratio must be less than or equal to 1e18");

        if (factory.getTokenImplementation(1) == address(0)) {
            factory.updateTokenImplementation(1, address(new BasicERC20(address(factory))));
        }

        if (!factory.isQuoteToken(wnative)) {
            factory.addQuoteToken(wnative);
        }

        uint256[] memory askPrices = new uint256[](2);

        askPrices[0] = 0;
        askPrices[1] = 1e18;

        uint256[] memory bidPrices = new uint256[](2);

        bidPrices[0] = askPrices[0] * ratio / 1e18;
        bidPrices[1] = askPrices[1] * ratio / 1e18;

        vm.prank(sender);
        (token, market) = factory.createMarketAndToken(
            1, "Test", "TST", wnative, 100_000_000e18, bidPrices, askPrices, abi.encode(18)
        );
    }
}

contract BadERC20 is BaseERC20 {
    constructor(address factory_) BaseERC20(factory_) {}

    function _update(address from, address to, uint256 value) internal override {
        unchecked {
            super._update(from, to, value + 1);
        }
    }
}
