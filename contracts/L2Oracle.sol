pragma solidity ^0.7.0;

import "arb-bridge-eth/contracts/bridge/interfaces/IInbox.sol";
import "arb-bridge-eth/contracts/bridge/interfaces/IOutbox.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "./PriceOracleGetter.sol";

contract L2Oracle {
    struct PriceFeed {
        uint256 linkPrice;
        uint256 lastUpdatedAt;
    }

    PriceFeed public priceFeed;

    address l1OracleAliased;
    address uniOralceL2;
    address chainlinkOracleL2;
    address sequencerUptimeFeed;

    uint256 constant MAX_DRIFT = 60 * 60 * 24 * 7 * 356 * 10000;

    function initialize(
        address _l1OracleAliased,
        address _uniOralceL2,
        address _chainlinkOracleL2,
        address _sequencerUptimeFeed
    ) public {
        require(_l1OracleAliased == address(0), "ALREADY_INIT");
        l1OracleAliased = _l1OracleAliased;
        uniOralceL2 = _uniOralceL2;
        chainlinkOracleL2 = _chainlinkOracleL2;
        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    modifier onlyFromL1Oracle() {
        require(msg.sender == l1OracleAliased, "NOT_FROM_L1_ORACLE");
        _;
    }

    function receiveOracleDataFromL1(
        uint256 sumL1OrackePrices,
        uint256 l1ChainlinkPriceUpdatedAt
    ) external onlyFromL1Oracle {
        (
            ,
            /*uint80 roundId*/
            int256 answer, /*uint256 updatedAt*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = AggregatorV3Interface(sequencerUptimeFeed).latestRoundData();

        require(answer == 1, "SEQUENCER_DOWN");

        (
            uint256 uniswapPrice,
            uint256 chainlinkPrice,
            uint256 l2chainlinkPriceUpdatedAt
        ) = PriceOracleGetter.getLinkPrices(uniOralceL2, chainlinkOracleL2);

        uint256 minChainLinkPricce = l1ChainlinkPriceUpdatedAt <
            l2chainlinkPriceUpdatedAt
            ? l1ChainlinkPriceUpdatedAt
            : l2chainlinkPriceUpdatedAt;
        require(block.timestamp > minChainLinkPricce, "NONSENSE_PRICE");
        require(
            block.timestamp - minChainLinkPricce < MAX_DRIFT,
            "PRICE_DRIFT"
        );

        priceFeed = PriceFeed(
            (sumL1OrackePrices + uniswapPrice + chainlinkPrice) / 4,
            block.timestamp
        );
    }
}
