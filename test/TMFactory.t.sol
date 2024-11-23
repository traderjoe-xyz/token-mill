// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract TMFactoryTest is Test {
    ITMFactory factory;
    address wnative;
    address proxyAdmin;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    address feeRecipient = makeAddr("FeeRecipient");
    address staking = makeAddr("TMStaking");

    function setUp() public {
        wnative = address(new WNative());

        address factoryImp = address(new TMFactory(staking, address(wnative)));
        factory = ITMFactory(
            address(
                new TransparentUpgradeableProxy(
                    factoryImp,
                    address(this),
                    abi.encodeCall(TMFactory.initialize, (0.2e4, 0.5e4, feeRecipient, address(this)))
                )
            )
        );

        proxyAdmin = address(uint160(uint256(vm.load(address(factory), ERC1967Utils.ADMIN_SLOT))));
    }

    function test_Constructor() public view {
        assertEq(Ownable(address(factory)).owner(), address(this), "test_Constructor::1");
        assertEq(factory.getDefaultProtocolShare(), 0.2e4, "test_Constructor::2");
        assertEq(factory.getProtocolFeeRecipient(), feeRecipient, "test_Constructor::3");
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

    function test_Fuzz_UpdateProtocolShare(uint16 pShares) public {
        pShares = uint16(bound(pShares, 0, 1e4));

        assertEq(factory.getDefaultProtocolShare(), 0.2e4, "test_Fuzz_UpdateProtocolShare::1");

        factory.updateProtocolShare(pShares);

        assertEq(factory.getDefaultProtocolShare(), pShares, "test_Fuzz_UpdateProtocolShare::2");

        vm.expectRevert(ITMFactory.TMFactory__InvalidProtocolShare.selector);
        factory.updateProtocolShare(uint16(bound(pShares, 1e4 + 1, type(uint16).max)));
    }

    function test_Fuzz_UpdateReferrerShare(uint16 referrerShares) public {
        uint16 rShares = uint16(bound(referrerShares, 0, 1e4));

        assertEq(factory.getReferrerShare(), 0.5e4, "test_Fuzz_UpdateReferrerShare::1");

        factory.updateReferrerShare(rShares);

        assertEq(factory.getReferrerShare(), rShares, "test_Fuzz_UpdateReferrerShare::2");

        factory.updateReferrerShare(0);

        assertEq(factory.getReferrerShare(), 0e4, "test_Fuzz_UpdateReferrerShare::3");

        vm.expectRevert(ITMFactory.TMFactory__InvalidReferrerShare.selector);
        factory.updateReferrerShare(uint16(bound(referrerShares, 1e4 + 1, type(uint16).max)));
    }

    function test_Fuzz_UpdateProtocolFeeRecipient(address recipient) public {
        assertEq(factory.getProtocolFeeRecipient(), feeRecipient, "test_Fuzz_UpdateProtocolFeeRecipient::1");

        recipient = recipient == address(0) ? alice : recipient;

        factory.updateProtocolFeeRecipient(recipient);

        assertEq(factory.getProtocolFeeRecipient(), recipient, "test_Fuzz_UpdateProtocolFeeRecipient::2");

        vm.expectRevert(ITMFactory.TMFactory__AddressZero.selector);
        factory.updateProtocolFeeRecipient(address(0));
    }

    function test_Fuzz_CreateTokenAndMarket(
        address sender,
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 amount,
        uint16 creatorShare,
        uint16 stakingShare
    ) public {
        vm.assume(sender != proxyAdmin);

        if (bytes(name).length == 0) name = "Token";
        if (bytes(symbol).length == 0) symbol = "T";

        decimals = uint8(bound(decimals, 0, 18));
        creatorShare = uint16(bound(creatorShare, 0, 0.8e4));
        stakingShare = 0.8e4 - creatorShare;

        TMERC20 implementation = new TMERC20(address(factory));
        factory.updateTokenImplementation(1, address(implementation));
        factory.addQuoteToken(wnative);

        uint256[] memory prices = new uint256[](2);
        prices[0] = 0;
        prices[1] = 1e18;

        amount = bound(amount, 10 ** decimals, uint256(type(uint128).max) * 10 ** decimals / 1e18);

        ITMFactory.MarketCreationParameters memory params = ITMFactory.MarketCreationParameters(
            1, name, symbol, wnative, amount, creatorShare, stakingShare, prices, prices, abi.encode(decimals)
        );

        vm.prank(sender);
        (address token, address market) = factory.createMarketAndToken(params);

        assertEq(factory.getCreatorOf(market), sender, "test_Fuzz_CreateTokenAndMarket::1");

        (uint256 pShare, uint256 cShare, uint256 sShare) = factory.getFeeSharesOf(market);

        assertEq(pShare, 0.2e4, "test_Fuzz_CreateTokenAndMarket::2");
        assertEq(cShare, creatorShare, "test_Fuzz_CreateTokenAndMarket::3");
        assertEq(sShare, stakingShare, "test_Fuzz_CreateTokenAndMarket::4");
        assertEq(factory.getTokenType(token), 1, "test_Fuzz_CreateTokenAndMarket::5");
        assertEq(factory.getMarketOf(token), market, "test_Fuzz_CreateTokenAndMarket::6");

        (bool tokenAisBase, address market_) = factory.getMarket(token, wnative);

        assertEq(tokenAisBase, true, "test_Fuzz_CreateTokenAndMarket::7");
        assertEq(market_, market, "test_Fuzz_CreateTokenAndMarket::8");

        (tokenAisBase, market_) = factory.getMarket(wnative, token);

        assertEq(tokenAisBase, false, "test_Fuzz_CreateTokenAndMarket::9");
        assertEq(market_, market, "test_Fuzz_CreateTokenAndMarket::10");

        assertEq(factory.getMarketsLength(), 1, "test_Fuzz_CreateTokenAndMarket::11");
        assertEq(factory.getMarketAt(0), market, "test_Fuzz_CreateTokenAndMarket::12");
    }

    function test_Fuzz_Revert_CreateTokenAndMarket(
        address token,
        uint96 tokenType,
        uint16 creatorShare,
        uint16 stakingShare
    ) public {
        token = address(uint160(bound(uint160(token), 0x0a, type(uint160).max)));
        tokenType = uint96(bound(tokenType, 1, type(uint96).max));

        vm.assume(token != address(factory));

        ITMFactory.MarketCreationParameters memory params;
        params.totalSupply = 1e18;

        vm.expectRevert(ITMFactory.TMFactory__InvalidTokenParameters.selector);
        factory.createMarketAndToken(params);

        params.name = "Token";

        vm.expectRevert(ITMFactory.TMFactory__InvalidTokenParameters.selector);
        factory.createMarketAndToken(params);

        params.symbol = "T";

        params.tokenType = tokenType;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 0;
        prices[1] = 1e18;
        params.bidPrices = prices;
        params.askPrices = prices;

        vm.expectRevert(ITMFactory.TMFactory__InvalidTokenType.selector);
        factory.createMarketAndToken(params);

        address badToken = address(new BadERC20(address(factory)));

        factory.updateTokenImplementation(tokenType, badToken);

        params.quoteToken = wnative;

        vm.expectRevert(ITMFactory.TMFactory__InvalidQuoteToken.selector);
        factory.createMarketAndToken(params);

        factory.addQuoteToken(wnative);

        uint256 total = uint256(creatorShare);

        stakingShare =
            uint16(bound(stakingShare, 0, total > 0.8e4 ? stakingShare : total < 0.8e4 ? 0.8e4 - total - 1 : 1));

        params.creatorShare = creatorShare;
        params.stakingShare = stakingShare;

        vm.expectRevert(ITMFactory.TMFactory__InvalidFeeShares.selector);
        factory.createMarketAndToken(params);

        params.creatorShare = 0.2e4;
        params.stakingShare = 0.6e4;

        vm.expectRevert(ITMFactory.TMFactory__InvalidBalance.selector);
        factory.createMarketAndToken(params);
    }

    function test_Fuzz_UpdateCreator(address sender, address other) public {
        if (sender == other) {
            unchecked {
                other = address(uint160(sender) + 1);
            }
        }

        vm.assume(sender != proxyAdmin && other != proxyAdmin && sender != address(0) && other != address(0));

        (, address market) = _setUpAndCreateToken(sender);

        assertEq(factory.getCreatorOf(market), sender, "test_Fuzz_UpdateCreator::1");
        assertEq(factory.getCreatorMarketsLength(sender), 1, "test_Fuzz_UpdateCreator::2");
        assertEq(factory.getCreatorMarketsLength(other), 0, "test_Fuzz_UpdateCreator::3");
        assertEq(factory.getCreatorMarketAt(sender, 0), market, "test_Fuzz_UpdateCreator::4");

        vm.prank(sender);
        factory.updateCreatorOf(market, other);

        assertEq(factory.getCreatorOf(market), other, "test_Fuzz_UpdateCreator::5");
        assertEq(factory.getCreatorMarketsLength(sender), 0, "test_Fuzz_UpdateCreator::6");
        assertEq(factory.getCreatorMarketsLength(other), 1, "test_Fuzz_UpdateCreator::7");
        assertEq(factory.getCreatorMarketAt(other, 0), market, "test_Fuzz_UpdateCreator::8");

        vm.expectRevert(ITMFactory.TMFactory__InvalidCaller.selector);
        vm.prank(sender);
        factory.updateCreatorOf(market, sender);

        vm.prank(other);
        factory.updateCreatorOf(market, sender);

        assertEq(factory.getCreatorOf(market), sender, "test_Fuzz_UpdateCreator::9");
        assertEq(factory.getCreatorMarketsLength(sender), 1, "test_Fuzz_UpdateCreator::10");
        assertEq(factory.getCreatorMarketsLength(other), 0, "test_Fuzz_UpdateCreator::11");
        assertEq(factory.getCreatorMarketAt(sender, 0), market, "test_Fuzz_UpdateCreator::12");
    }

    function test_UpdateCreator() public {
        address creator0 = makeAddr("Creator0");
        address creator1 = makeAddr("Creator1");

        (, address market0) = _setUpAndCreateToken(creator0);
        (, address market1) = _setUpAndCreateToken(creator0);
        (, address market2) = _setUpAndCreateToken(creator0);
        (, address market3) = _setUpAndCreateToken(creator1);

        assertEq(factory.getCreatorOf(market0), creator0, "test_UpdateCreator::1");
        assertEq(factory.getCreatorOf(market1), creator0, "test_UpdateCreator::2");
        assertEq(factory.getCreatorOf(market2), creator0, "test_UpdateCreator::3");
        assertEq(factory.getCreatorOf(market3), creator1, "test_UpdateCreator::4");

        assertEq(factory.getCreatorMarketsLength(creator0), 3, "test_UpdateCreator::5");
        assertEq(factory.getCreatorMarketsLength(creator1), 1, "test_UpdateCreator::6");

        assertEq(factory.getCreatorMarketAt(creator0, 0), market0, "test_UpdateCreator::7");
        assertEq(factory.getCreatorMarketAt(creator0, 1), market1, "test_UpdateCreator::8");
        assertEq(factory.getCreatorMarketAt(creator0, 2), market2, "test_UpdateCreator::9");
        assertEq(factory.getCreatorMarketAt(creator1, 0), market3, "test_UpdateCreator::10");

        vm.prank(creator0);
        factory.updateCreatorOf(market0, creator1);

        assertEq(factory.getCreatorOf(market0), creator1, "test_UpdateCreator::11");
        assertEq(factory.getCreatorOf(market1), creator0, "test_UpdateCreator::12");
        assertEq(factory.getCreatorOf(market2), creator0, "test_UpdateCreator::13");
        assertEq(factory.getCreatorOf(market3), creator1, "test_UpdateCreator::14");

        assertEq(factory.getCreatorMarketsLength(creator0), 2, "test_UpdateCreator::15");
        assertEq(factory.getCreatorMarketsLength(creator1), 2, "test_UpdateCreator::16");

        assertEq(factory.getCreatorMarketAt(creator0, 0), market2, "test_UpdateCreator::17");
        assertEq(factory.getCreatorMarketAt(creator0, 1), market1, "test_UpdateCreator::18");
        assertEq(factory.getCreatorMarketAt(creator1, 0), market3, "test_UpdateCreator::19");
        assertEq(factory.getCreatorMarketAt(creator1, 1), market0, "test_UpdateCreator::20");

        vm.prank(creator0);
        factory.updateCreatorOf(market1, creator1);

        assertEq(factory.getCreatorOf(market0), creator1, "test_UpdateCreator::21");
        assertEq(factory.getCreatorOf(market1), creator1, "test_UpdateCreator::22");
        assertEq(factory.getCreatorOf(market2), creator0, "test_UpdateCreator::23");
        assertEq(factory.getCreatorOf(market3), creator1, "test_UpdateCreator::24");

        assertEq(factory.getCreatorMarketsLength(creator0), 1, "test_UpdateCreator::25");
        assertEq(factory.getCreatorMarketsLength(creator1), 3, "test_UpdateCreator::26");

        assertEq(factory.getCreatorMarketAt(creator0, 0), market2, "test_UpdateCreator::27");
        assertEq(factory.getCreatorMarketAt(creator1, 0), market3, "test_UpdateCreator::28");
        assertEq(factory.getCreatorMarketAt(creator1, 1), market0, "test_UpdateCreator::29");
        assertEq(factory.getCreatorMarketAt(creator1, 2), market1, "test_UpdateCreator::30");

        vm.prank(creator1);
        factory.updateCreatorOf(market3, creator0);

        assertEq(factory.getCreatorOf(market0), creator1, "test_UpdateCreator::31");
        assertEq(factory.getCreatorOf(market1), creator1, "test_UpdateCreator::32");
        assertEq(factory.getCreatorOf(market2), creator0, "test_UpdateCreator::33");
        assertEq(factory.getCreatorOf(market3), creator0, "test_UpdateCreator::34");

        assertEq(factory.getCreatorMarketsLength(creator0), 2, "test_UpdateCreator::35");
        assertEq(factory.getCreatorMarketsLength(creator1), 2, "test_UpdateCreator::36");

        assertEq(factory.getCreatorMarketAt(creator0, 0), market2, "test_UpdateCreator::37");
        assertEq(factory.getCreatorMarketAt(creator0, 1), market3, "test_UpdateCreator::38");
        assertEq(factory.getCreatorMarketAt(creator1, 0), market1, "test_UpdateCreator::39");
        assertEq(factory.getCreatorMarketAt(creator1, 1), market0, "test_UpdateCreator::40");

        vm.prank(creator1);
        factory.updateCreatorOf(market1, creator1);

        assertEq(factory.getCreatorOf(market0), creator1, "test_UpdateCreator::41");
        assertEq(factory.getCreatorOf(market1), creator1, "test_UpdateCreator::42");
        assertEq(factory.getCreatorOf(market2), creator0, "test_UpdateCreator::43");
        assertEq(factory.getCreatorOf(market3), creator0, "test_UpdateCreator::44");

        assertEq(factory.getCreatorMarketsLength(creator0), 2, "test_UpdateCreator::45");
        assertEq(factory.getCreatorMarketsLength(creator1), 2, "test_UpdateCreator::46");

        assertEq(factory.getCreatorMarketAt(creator0, 0), market2, "test_UpdateCreator::47");
        assertEq(factory.getCreatorMarketAt(creator0, 1), market3, "test_UpdateCreator::48");
        assertEq(factory.getCreatorMarketAt(creator1, 0), market0, "test_UpdateCreator::49");
        assertEq(factory.getCreatorMarketAt(creator1, 1), market1, "test_UpdateCreator::50");
    }

    struct Fees {
        uint256 protocolFees;
        uint256 creatorFees;
        uint256 stakingFees;
    }

    function test_Fuzz_UpdateFeeShareOf(uint16 cShares, uint16 sShares) public {
        cShares = uint16(bound(cShares, 0, 0.8e4));
        sShares = 0.8e4 - cShares;

        (, address market1) = _setUpAndCreateToken(alice);
        (, address market2) = _setUpAndCreateToken(bob);

        Fees memory fees1;
        Fees memory fees2;

        (fees1.protocolFees, fees1.creatorFees, fees1.stakingFees) = factory.getFeeSharesOf(market1);
        (fees2.protocolFees, fees2.creatorFees, fees2.stakingFees) = factory.getFeeSharesOf(market2);

        assertEq(fees1.protocolFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::1");
        assertEq(fees1.creatorFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::2");
        assertEq(fees1.stakingFees, 0.6e4, "test_Fuzz_UpdateFeeShareOf::3");

        assertEq(fees2.protocolFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::4");
        assertEq(fees2.creatorFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::5");
        assertEq(fees2.stakingFees, 0.6e4, "test_Fuzz_UpdateFeeShareOf::6");

        vm.prank(alice);
        factory.updateFeeSharesOf(market1, cShares, sShares);

        (fees1.protocolFees, fees1.creatorFees, fees1.stakingFees) = factory.getFeeSharesOf(market1);
        (fees2.protocolFees, fees2.creatorFees, fees2.stakingFees) = factory.getFeeSharesOf(market2);

        assertEq(fees1.protocolFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::7");
        assertEq(fees1.creatorFees, cShares, "test_Fuzz_UpdateFeeShareOf::8");
        assertEq(fees1.stakingFees, sShares, "test_Fuzz_UpdateFeeShareOf::9");

        assertEq(fees2.protocolFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::10");
        assertEq(fees2.creatorFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::11");
        assertEq(fees2.stakingFees, 0.6e4, "test_Fuzz_UpdateFeeShareOf::12");

        vm.prank(bob);
        factory.updateFeeSharesOf(market2, cShares, sShares);

        (fees1.protocolFees, fees1.creatorFees, fees1.stakingFees) = factory.getFeeSharesOf(market1);
        (fees2.protocolFees, fees2.creatorFees, fees2.stakingFees) = factory.getFeeSharesOf(market2);

        assertEq(fees1.protocolFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::13");
        assertEq(fees1.creatorFees, cShares, "test_Fuzz_UpdateFeeShareOf::14");
        assertEq(fees1.stakingFees, sShares, "test_Fuzz_UpdateFeeShareOf::15");

        assertEq(fees2.protocolFees, 0.2e4, "test_Fuzz_UpdateFeeShareOf::16");
        assertEq(fees2.creatorFees, cShares, "test_Fuzz_UpdateFeeShareOf::17");
        assertEq(fees2.stakingFees, sShares, "test_Fuzz_UpdateFeeShareOf::18");

        uint256 total = cShares;
        if (total == 0.8e4) sShares = 1;
        else if (total < 0.8e4) sShares = uint16(bound(sShares, 0, 0.8e4 - total - 1));

        vm.expectRevert(ITMFactory.TMFactory__InvalidFeeShares.selector);
        vm.prank(alice);
        factory.updateFeeSharesOf(market1, cShares, sShares);

        vm.expectRevert(ITMFactory.TMFactory__InvalidFeeShares.selector);
        vm.prank(bob);
        factory.updateFeeSharesOf(market2, cShares, sShares);

        vm.expectRevert(ITMFactory.TMFactory__InvalidCaller.selector);
        vm.prank(alice);
        factory.updateFeeSharesOf(market2, 0, 0);

        vm.expectRevert(ITMFactory.TMFactory__InvalidCaller.selector);
        vm.prank(bob);
        factory.updateFeeSharesOf(market1, 0, 0);
    }

    struct FeesClaimed {
        uint256 protocol;
        uint256 amount;
    }

    struct PendingFees {
        uint256 protocolFees;
        uint256 referrerFees;
        uint256 creatorFees;
        uint256 stakingFees;
    }

    function test_ClaimFees() public {
        (address token1, address market1) = _setUpAndCreateToken(alice, 0.5e18);

        factory.updateReferrerShare(0.2e4);

        Router router = new Router(address(0), address(0), address(0), address(0), address(factory), address(wnative));

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token1);

        (,, uint256 quoteFees) = ITMMarket(market1).getDeltaAmounts(1e18, false);

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, alice);

        uint256 balance = IERC20(wnative).balanceOf(address(factory));

        Fees memory pendingFees1;
        (pendingFees1.creatorFees, pendingFees1.stakingFees) = ITMMarket(market1).getPendingFees();

        assertEq(pendingFees1.creatorFees + pendingFees1.stakingFees + balance, quoteFees, "test_ClaimFees::1");
        assertEq(pendingFees1.creatorFees, quoteFees * 0.2e4 / 1e4, "test_ClaimFees::2");
        assertEq(pendingFees1.stakingFees, quoteFees * 0.6e4 / 1e4, "test_ClaimFees::3");
        assertEq(balance, quoteFees * 0.2e4 / 1e4, "test_ClaimFees::4");

        vm.prank(staking);
        uint256 stakingClaimed = factory.claimFees(market1);

        assertEq(stakingClaimed, pendingFees1.stakingFees, "test_ClaimFees::5");
        assertGt(pendingFees1.creatorFees, 0, "test_ClaimFees::6");
        assertGt(pendingFees1.stakingFees, 0, "test_ClaimFees::7");

        assertEq(IERC20(wnative).balanceOf(staking), stakingClaimed, "test_ClaimFees::8");

        {
            Fees memory pendingFees;

            (pendingFees.creatorFees, pendingFees.stakingFees) = ITMMarket(market1).getPendingFees();

            assertEq(pendingFees.creatorFees, pendingFees1.creatorFees, "test_ClaimFees::9");
            assertEq(pendingFees.stakingFees, 0, "test_ClaimFees::10");
        }

        (,, quoteFees) = ITMMarket(market1).getDeltaAmounts(1e18, false);

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, address(0));

        uint256 amount = IERC20(wnative).balanceOf(address(factory)) - balance;
        balance += amount;

        Fees memory pendingFees2;
        (pendingFees2.creatorFees, pendingFees2.stakingFees) = ITMMarket(market1).getPendingFees();

        assertEq(amount, quoteFees * 0.2e4 / 1e4, "test_ClaimFees::11");
        assertEq(pendingFees2.creatorFees, pendingFees1.creatorFees + quoteFees * 0.2e4 / 1e4, "test_ClaimFees::12");
        assertEq(pendingFees2.stakingFees, pendingFees1.stakingFees, "test_ClaimFees::13");

        assertApproxEqAbs(pendingFees2.creatorFees, 2 * pendingFees1.creatorFees, 1, "test_ClaimFees::14");
        assertApproxEqAbs(pendingFees2.stakingFees, pendingFees1.stakingFees, 1, "test_ClaimFees::15");

        uint256 creatorClaimed;

        vm.prank(alice);
        creatorClaimed = factory.claimFees(market1);

        assertEq(creatorClaimed, pendingFees2.creatorFees, "test_ClaimFees::16");

        assertEq(IERC20(wnative).balanceOf(alice), creatorClaimed, "test_ClaimFees::17");

        {
            Fees memory pendingFees;

            (pendingFees.creatorFees, pendingFees.stakingFees) = ITMMarket(market1).getPendingFees();

            assertEq(pendingFees.creatorFees, 0, "test_ClaimFees::18");
            assertEq(pendingFees.stakingFees, pendingFees2.stakingFees, "test_ClaimFees::19");

            (pendingFees.creatorFees, pendingFees.stakingFees) = ITMMarket(market1).getPendingFees();

            assertEq(pendingFees.creatorFees, 0, "test_ClaimFees::20");
            assertEq(pendingFees.stakingFees, pendingFees2.stakingFees, "test_ClaimFees::21");
        }

        uint256 stakingClaimed2;

        vm.prank(staking);
        stakingClaimed2 = factory.claimFees(market1);

        assertEq(stakingClaimed2, pendingFees2.stakingFees, "test_ClaimFees::22");

        assertEq(IERC20(wnative).balanceOf(staking), stakingClaimed + stakingClaimed2, "test_ClaimFees::23");

        {
            Fees memory pendingFees;

            (pendingFees.creatorFees, pendingFees.stakingFees) = ITMMarket(market1).getPendingFees();

            assertEq(pendingFees.creatorFees, 0, "test_ClaimFees::24");
            assertEq(pendingFees.stakingFees, 0, "test_ClaimFees::25");
        }

        (,, quoteFees) = ITMMarket(market1).getDeltaAmounts(1e18, false);

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, address(0));

        amount = IERC20(wnative).balanceOf(address(factory)) - balance;

        Fees memory pendingFees3;

        (pendingFees3.creatorFees, pendingFees3.stakingFees) = ITMMarket(market1).getPendingFees();

        assertEq(amount, quoteFees * 0.2e4 / 1e4, "test_ClaimFees::26");
        assertEq(pendingFees3.creatorFees, quoteFees * 0.2e4 / 1e4, "test_ClaimFees::27");
        assertApproxEqAbs(pendingFees3.stakingFees, quoteFees * 0.6e4 / 1e4, 1, "test_ClaimFees::28");

        assertApproxEqAbs(pendingFees3.creatorFees, pendingFees1.creatorFees, 1, "test_ClaimFees::29");
        assertApproxEqAbs(pendingFees3.stakingFees, pendingFees1.stakingFees, 1, "test_ClaimFees::30");
    }

    function test_Fuzz_ClaimReferrerFees() public {
        (address token1, address market1) = _setUpAndCreateToken(alice, 0.5e18);

        factory.updateReferrerShare(0.3e4);

        Router router = new Router(address(0), address(0), address(0), address(0), address(factory), address(wnative));

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token1);

        (,, uint256 quoteFees) = ITMMarket(market1).getDeltaAmounts(1e18, false);
        uint256 protocolFees1 = quoteFees * 0.2e4 / 1e4;

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, alice);

        assertEq(
            factory.getReferrerFeesOf(address(wnative), alice),
            protocolFees1 * 0.3e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::1"
        );
        assertEq(
            factory.getProtocolFees(address(wnative)), protocolFees1 * 0.7e4 / 1e4, "test_Fuzz_ClaimReferrerFees::2"
        );
        assertEq(IERC20(wnative).balanceOf(address(factory)), protocolFees1, "test_Fuzz_ClaimReferrerFees::3");

        (,, quoteFees) = ITMMarket(market1).getDeltaAmounts(1e18, false);
        uint256 protocolFees2 = quoteFees * 0.2e4 / 1e4;

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, bob);

        assertEq(
            factory.getReferrerFeesOf(address(wnative), bob),
            protocolFees2 * 0.3e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::4"
        );
        assertEq(
            factory.getProtocolFees(address(wnative)),
            (protocolFees1 + protocolFees2) * 0.7e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::5"
        );

        vm.prank(alice);
        assertEq(
            factory.claimReferrerFees(address(wnative)), protocolFees1 * 0.3e4 / 1e4, "test_Fuzz_ClaimReferrerFees::6"
        );
        assertEq(IERC20(wnative).balanceOf(alice), protocolFees1 * 0.3e4 / 1e4, "test_Fuzz_ClaimReferrerFees::7");

        assertEq(factory.getReferrerFeesOf(address(wnative), alice), 0, "test_Fuzz_ClaimReferrerFees::8");
        assertEq(
            factory.getReferrerFeesOf(address(wnative), bob),
            protocolFees2 * 0.3e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::9"
        );
        assertEq(
            factory.getProtocolFees(address(wnative)),
            (protocolFees1 + protocolFees2) * 0.7e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::10"
        );

        factory.updateReferrerShare(0.55e4);

        (,, quoteFees) = ITMMarket(market1).getDeltaAmounts(1e18, false);
        uint256 protocolFees3 = quoteFees * 0.2e4 / 1e4;

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, alice);

        assertEq(
            factory.getReferrerFeesOf(address(wnative), alice),
            protocolFees3 * 0.55e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::11"
        );
        assertEq(
            factory.getReferrerFeesOf(address(wnative), bob),
            protocolFees2 * 0.3e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::12"
        );
        assertEq(
            factory.getProtocolFees(address(wnative)),
            (protocolFees1 + protocolFees2) * 0.7e4 / 1e4 + protocolFees3 * 0.45e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::13"
        );

        vm.prank(bob);
        assertEq(
            factory.claimReferrerFees(address(wnative)), protocolFees2 * 0.3e4 / 1e4, "test_Fuzz_ClaimReferrerFees::14"
        );

        assertEq(IERC20(wnative).balanceOf(bob), protocolFees2 * 0.3e4 / 1e4, "test_Fuzz_ClaimReferrerFees::15");

        vm.prank(feeRecipient);
        assertEq(
            factory.claimProtocolFees(address(wnative)),
            (protocolFees1 + protocolFees2) * 0.7e4 / 1e4 + protocolFees3 * 0.45e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::16"
        );

        assertEq(
            IERC20(wnative).balanceOf(feeRecipient),
            (protocolFees1 + protocolFees2) * 0.7e4 / 1e4 + protocolFees3 * 0.45e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::17"
        );

        assertEq(
            factory.getReferrerFeesOf(address(wnative), alice),
            protocolFees3 * 0.55e4 / 1e4,
            "test_Fuzz_ClaimReferrerFees::18"
        );
        assertEq(factory.getReferrerFeesOf(address(wnative), bob), 0, "test_Fuzz_ClaimReferrerFees::19");
        assertEq(factory.getProtocolFees(address(wnative)), 0, "test_Fuzz_ClaimReferrerFees::20");

        vm.prank(alice);
        assertEq(factory.claimReferrerFees(address(0)), protocolFees3 * 0.55e4 / 1e4, "test_Fuzz_ClaimReferrerFees::21");

        assertEq(IERC20(wnative).balanceOf(alice), protocolFees1 * 0.3e4 / 1e4, "test_Fuzz_ClaimReferrerFees::22");
        assertEq(alice.balance, protocolFees3 * 0.55e4 / 1e4, "test_Fuzz_ClaimReferrerFees::23");

        assertEq(factory.getReferrerFeesOf(address(wnative), alice), 0, "test_Fuzz_ClaimReferrerFees::24");
        assertEq(factory.getReferrerFeesOf(address(wnative), bob), 0, "test_Fuzz_ClaimReferrerFees::25");
        assertEq(factory.getProtocolFees(address(wnative)), 0, "test_Fuzz_ClaimReferrerFees::26");
    }

    function test_ClaimFeesAndUpdateProtocolFees() public {
        (address token1, address market1) = _setUpAndCreateToken(alice, 0.5e18);

        Router router = new Router(address(0), address(0), address(0), address(0), address(factory), address(wnative));

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token1);

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, alice);

        Fees memory pendingFees1;

        (pendingFees1.creatorFees, pendingFees1.stakingFees) = ITMMarket(market1).getPendingFees();

        assertGt(pendingFees1.creatorFees, 0, "test_ClaimFeesAndUpdateProtocolFees::1");
        assertGt(pendingFees1.stakingFees, 0, "test_ClaimFeesAndUpdateProtocolFees::2");

        vm.prank(alice);
        factory.updateFeeSharesOf(market1, 0, 0.8e4);

        Fees memory pendingFees2;

        (pendingFees2.creatorFees, pendingFees2.stakingFees) = ITMMarket(market1).getPendingFees();

        assertEq(pendingFees2.creatorFees, 0, "test_ClaimFeesAndUpdateProtocolFees::3");
        assertEq(pendingFees2.stakingFees, pendingFees1.stakingFees, "test_ClaimFeesAndUpdateProtocolFees::4");
        assertEq(IERC20(wnative).balanceOf(alice), pendingFees1.creatorFees, "test_ClaimFeesAndUpdateProtocolFees::5");

        router.swapExactIn{value: 1e18}(route, address(1), 1e18, 0, block.timestamp, alice);

        Fees memory pendingFees3;

        (pendingFees3.creatorFees, pendingFees3.stakingFees) = ITMMarket(market1).getPendingFees();

        assertEq(pendingFees3.creatorFees, 0, "test_ClaimFeesAndUpdateProtocolFees::6");
        assertEq(
            pendingFees3.stakingFees,
            2 * pendingFees1.stakingFees + pendingFees1.creatorFees,
            "test_ClaimFeesAndUpdateProtocolFees::7"
        );
    }

    function _setUpAndCreateToken(address sender) internal returns (address token, address market) {
        return _setUpAndCreateToken(sender, 1e18);
    }

    function _setUpAndCreateToken(address sender, uint256 ratio) internal returns (address token, address market) {
        require(ratio <= 1e18, "Ratio must be less than or equal to 1e18");

        if (factory.getTokenImplementation(1) == address(0)) {
            factory.updateTokenImplementation(1, address(new TMERC20(address(factory))));
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

        ITMFactory.MarketCreationParameters memory params = ITMFactory.MarketCreationParameters(
            1, "Test", "TST", wnative, 100_000_000e18, 0.2e4, 0.6e4, bidPrices, askPrices, abi.encode(18)
        );

        vm.prank(sender);
        (token, market) = factory.createMarketAndToken(params);
    }
}

contract BadERC20 is TMBaseERC20 {
    constructor(address factory_) TMBaseERC20(factory_) {}

    function _update(address from, address to, uint256 value) internal override {
        unchecked {
            super._update(from, to, value + 1);
        }
    }
}
