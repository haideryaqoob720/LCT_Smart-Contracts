// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LctPrice {
    AggregatorV3Interface internal priceFeed;
    address public ltcPriceAdmin;
    address public ltcPriceOwner;
    bool public tokenIntegratedWithChainlink;
    int public staticTokenPrice; // 0.00004628

    modifier onlyOwner() {
        require(
            ltcPriceOwner == msg.sender,
            "Ownable: caller is not the owner"
        );
        _;
    }

    function storeConstructor(address _aggregatorAddress) public {
        priceFeed = AggregatorV3Interface(_aggregatorAddress);
        ltcPriceAdmin = msg.sender;
        ltcPriceOwner = msg.sender;
        staticTokenPrice = 46280000000000; // 0.00004628
    }

    function handleSetLtcAdmin(address _adminAddr) public onlyOwner {
        ltcPriceAdmin = _adminAddr;
    }

    function handleSetLtcOwner(address _ownerAddr) public onlyOwner {
        ltcPriceOwner = _ownerAddr;
    }

    function handleTokenIntegratedWithChainlink(bool _status) public onlyOwner {
        tokenIntegratedWithChainlink = _status;
    }

    /**
     * Returns the latest price.
     */

    function handleSetAgregatorAddress(address _tokenAddress) public onlyOwner {
        priceFeed = AggregatorV3Interface(_tokenAddress);
    }

    function getLatestPriceFromAgregator() internal view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price * 10000000000;
    }

    function handleSetTokenPrice(int _livePrice) public returns (int) {
        require(msg.sender == ltcPriceAdmin, "You are not admin");
        staticTokenPrice = _livePrice;
        return _livePrice;
    }

    function getTokenPrice() public view returns (int) {
        int tokenPrice;
        if (tokenIntegratedWithChainlink == true) {
            tokenPrice = getLatestPriceFromAgregator();
        } else {
            tokenPrice = staticTokenPrice;
        }
        return tokenPrice;
    }
}
