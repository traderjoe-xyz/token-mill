// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title V2 Pair Interface
 * @dev Interface of the V2 pair contract.
 */
interface IV2_0Pair {
    struct FeeParameters {
        uint16 binStep;
        uint16 baseFactor;
        uint16 filterPeriod;
        uint16 decayPeriod;
        uint16 reductionFactor;
        uint24 variableFeeControl;
        uint16 protocolShare;
        uint24 maxVolatilityAccumulated;
        uint24 volatilityAccumulated;
        uint24 volatilityReference;
        uint24 indexRef;
        uint40 time;
    }

    struct FeesDistribution {
        uint128 total;
        uint128 protocol;
    }

    struct Bin {
        uint112 reserveX;
        uint112 reserveY;
        uint256 accTokenXPerShare;
        uint256 accTokenYPerShare;
    }

    struct PairInformation {
        uint24 activeId;
        uint136 reserveX;
        uint136 reserveY;
        uint16 oracleSampleLifetime;
        uint16 oracleSize;
        uint16 oracleActiveSize;
        uint40 oracleLastTimestamp;
        uint16 oracleId;
        FeesDistribution feesX;
        FeesDistribution feesY;
    }

    struct Debts {
        uint256 debtX;
        uint256 debtY;
    }

    struct Fees {
        uint128 tokenX;
        uint128 tokenY;
    }

    struct MintInfo {
        uint256 amountXIn;
        uint256 amountYIn;
        uint256 amountXAddedToPair;
        uint256 amountYAddedToPair;
        uint256 activeFeeX;
        uint256 activeFeeY;
        uint256 totalDistributionX;
        uint256 totalDistributionY;
        uint256 id;
        uint256 amountX;
        uint256 amountY;
        uint256 distributionX;
        uint256 distributionY;
    }

    event Swap(
        address indexed sender,
        address indexed recipient,
        uint256 indexed id,
        bool swapForY,
        uint256 amountIn,
        uint256 amountOut,
        uint256 volatilityAccumulated,
        uint256 fees
    );

    event FlashLoan(address indexed sender, address indexed receiver, address token, uint256 amount, uint256 fee);

    event CompositionFee(
        address indexed sender, address indexed recipient, uint256 indexed id, uint256 feesX, uint256 feesY
    );

    event DepositedToBin(
        address indexed sender, address indexed recipient, uint256 indexed id, uint256 amountX, uint256 amountY
    );

    event WithdrawnFromBin(
        address indexed sender, address indexed recipient, uint256 indexed id, uint256 amountX, uint256 amountY
    );

    event FeesCollected(address indexed sender, address indexed recipient, uint256 amountX, uint256 amountY);

    event ProtocolFeesCollected(address indexed sender, address indexed recipient, uint256 amountX, uint256 amountY);

    event OracleSizeIncreased(uint256 previousSize, uint256 newSize);

    function tokenX() external view returns (address);

    function tokenY() external view returns (address);

    function factory() external view returns (address);

    function getReservesAndId() external view returns (uint256 reserveX, uint256 reserveY, uint256 activeId);

    function getGlobalFees()
        external
        view
        returns (uint128 feesXTotal, uint128 feesYTotal, uint128 feesXProtocol, uint128 feesYProtocol);

    function getOracleParameters()
        external
        view
        returns (
            uint256 oracleSampleLifetime,
            uint256 oracleSize,
            uint256 oracleActiveSize,
            uint256 oracleLastTimestamp,
            uint256 oracleId,
            uint256 min,
            uint256 max
        );

    function getOracleSampleFrom(uint256 timeDelta)
        external
        view
        returns (uint256 cumulativeId, uint256 cumulativeAccumulator, uint256 cumulativeBinCrossed);

    function feeParameters() external view returns (FeeParameters memory);

    function findFirstNonEmptyBinId(uint24 id_, bool sentTokenY) external view returns (uint24 id);

    function getBin(uint24 id) external view returns (uint256 reserveX, uint256 reserveY);

    function pendingFees(address account, uint256[] memory ids)
        external
        view
        returns (uint256 amountX, uint256 amountY);

    function swap(bool sentTokenY, address to) external returns (uint256 amountXOut, uint256 amountYOut);

    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external;

    function mint(
        uint256[] calldata ids,
        uint256[] calldata distributionX,
        uint256[] calldata distributionY,
        address to
    ) external returns (uint256 amountXAddedToPair, uint256 amountYAddedToPair, uint256[] memory liquidityMinted);

    function burn(uint256[] calldata ids, uint256[] calldata amounts, address to)
        external
        returns (uint256 amountX, uint256 amountY);

    function increaseOracleLength(uint16 newSize) external;

    function collectFees(address account, uint256[] calldata ids) external returns (uint256 amountX, uint256 amountY);

    function collectProtocolFees() external returns (uint128 amountX, uint128 amountY);

    function setFeesParameters(bytes32 packedFeeParameters) external;

    function forceDecay() external;

    function initialize(
        address tokenX,
        address tokenY,
        uint24 activeId,
        uint16 sampleLifetime,
        bytes32 packedFeeParameters
    ) external;
}
