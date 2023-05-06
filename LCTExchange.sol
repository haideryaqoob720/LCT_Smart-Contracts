// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

// Openzeppelin Imports
import "@openzeppelin/contracts/access/Ownable.sol";

// Local Imports
import "./DaiToken.sol";

interface LCTLivePriceInterface {
    function getTokenPrice() external view returns (uint);
}

contract LCTExchange is Ownable {
    DaiToken public token;
    string public name;
    address ownerWalletAddress;
    address lctLivePriceInterfaceAddr;

    mapping(address => uint256) public stakingBalance;
    // mapping(address => bool) public isStaking;
    mapping(address => uint256) public stakes;
    mapping(address => S_liquidity[]) public liqudityProviders;

    address[] public stakers;
    Stakeholder[] public stakeholders;

    event TokensPurchased(
        address account,
        address token,
        uint256 amount,
        uint256 rateLCT
    );
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 index,
        uint256 timestamp
    );

    struct Stake {
        uint256 amount;
        uint256 since;
        uint32 timeStaked;
        uint256 stakeStatus;
        address user;
        bool claimable;
    }

    struct S_liquidity {
        uint amount;
        uint sinse;
    }

    struct Stakeholder {
        address user;
        Stake[] address_stakes;
    }

    // END LIQUIDITY STATES

    // modifier handleWithdrawFundsModifier() {
    //     require(msg.sender == ownerWalletAddress);
    //     _;
    // }

    // constructor(IERC20Upgradeable _token, string memory _name) public {
    constructor(
        DaiToken _token,
        string memory _name,
        address _livePriceInterfaceAddress
    ) public {
        stakeholders.push();
        token = _token;
        name = _name;
        ownerWalletAddress = msg.sender;
        lctLivePriceInterfaceAddr = _livePriceInterfaceAddress;
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    function handleSetInterfaceAddress(
        address _interfaceAddr
    ) public onlyOwner {
        lctLivePriceInterfaceAddr = _interfaceAddr;
    }

    function getLivePriceFromInheritance() public view returns (uint) {
        return LCTLivePriceInterface(lctLivePriceInterfaceAddr).getTokenPrice();
    }

    function userHistoryOfStake() external view returns (Stakeholder memory) {
        uint256 index = stakes[msg.sender];
        return stakeholders[index];
    }

    function exchangeHistoryOfStake()
        external
        view
        returns (Stakeholder[] memory)
    {
        return stakeholders;
    }

    function adminWithdraw(
        address payable recipient
    ) external payable onlyOwner {
        recipient.transfer(address(this).balance);
    }

    function adminWithdrawToken() external payable onlyOwner {
        token.transfer(ownerWalletAddress, token.balanceOf(address(this)));
    }

    function buyTokens() public payable returns (uint, uint) {
        require(msg.value > 0, "Send ETH to buy some tokens");

        // uint256 tokenAmount = msg.value / livePriceRate; // 1 / 0.00004628 = 21607.605877269
        uint256 tokenAmount2 = msg.value / getLivePriceFromInheritance();
        uint256 tokenAmount = tokenAmount2 * 1000000000000000000;

        require(
            token.balanceOf(address(this)) >= tokenAmount,
            "Vendor contract has not enough tokens in its balance"
        );

        // Transfer token to the msg.sender
        bool sent = token.transfer(msg.sender, tokenAmount);
        require(sent, "Failed to transfer token to user");

        emit TokensPurchased(
            msg.sender,
            address(token),
            tokenAmount,
            getLivePriceFromInheritance()
        );

        return (getLivePriceFromInheritance(), msg.value);
    }

    function _addStakeholder(address staker) internal returns (uint) {
        stakeholders.push();
        uint userIndex = stakeholders.length - 1;
        stakeholders[userIndex].user = staker;
        stakes[staker] = userIndex;
        return userIndex;
    }

    function stakeTokens(
        uint256 _amount,
        uint32 _timeStaked, // timestaked will be in months Ex. 12,6,3,1
        uint256 status
    ) public {
        // Check that the requested amount of tokens to sell is more than 0
        require(_amount > 0, "Cannot stake nothing");

        // Check that the user's token balance is enough to do the swap
        uint256 userBalance = token.balanceOf(msg.sender);
        require(
            userBalance >= _amount,
            "Your balance is lower than the amount of tokens you want to stake"
        );

        uint256 index = stakes[msg.sender];
        if (index == 0) {
            index = _addStakeholder(msg.sender);
        }
        stakingBalance[msg.sender] += _amount;
        // isStaking[msg.sender] = true;

        bool sent = token.transferFrom(msg.sender, address(this), _amount);
        require(sent, "Failed to transfer tokens from user to vendor");

        stakeholders[index].address_stakes.push(
            Stake(
                _amount,
                block.timestamp,
                _timeStaked,
                status,
                msg.sender,
                true
            )
        );
        emit Staked(msg.sender, _amount, index, block.timestamp);
    }

    function help_withdrawCheckTimePassedOrNot(
        uint256 _currentTimeStakedSince,
        uint32 stakedTimePeriod
    ) private view returns (bool) {
        //Example: 1677136837   >  (1674458437    +       (2678400 * 12))

        bool answer;
        if (_currentTimeStakedSince == stakedTimePeriod) {
            if (
                block.timestamp >
                _currentTimeStakedSince + (2678400 * stakedTimePeriod)
            ) {
                answer = true;
            } else {
                answer = false;
            }
        }
        return answer;
    }

    function _withdrawStake(uint256 index) public {
        // require(index < stakes[msg.sender].address_stakes.length, "Invalid stake index.");

        uint256 user_index = stakes[msg.sender];
        Stake memory current_stake = stakeholders[user_index].address_stakes[
            index
        ];
        if (current_stake.claimable == true) {
            // If we not have to put 2 minutes testing
            // bool responseTimePassed = help_withdrawCheckTimePassedOrNot(
            //     current_stake.since,
            //     current_stake.timeStaked
            // );
            // require(
            //     responseTimePassed == true,
            //     "You have to wait for the time, which selected in stake"
            // );

            bool responseTimePassed;
            // We also creted two minute stake test this two is two Minute stake test
            // if it is not two minute test then check the time is pass or not
            if (current_stake.timeStaked != 2) {
                responseTimePassed = help_withdrawCheckTimePassedOrNot(
                    current_stake.since,
                    current_stake.timeStaked
                );
                require(
                    responseTimePassed == true,
                    "You have to wait for the time, which selected in stake"
                );
            }
            stakeholders[user_index].address_stakes[index].claimable = false;

            // uint256 timeDiffrence = block.timestamp - current_stake.since;
            // timeStaked ======= 12, 6, 3, 1, and 2 minute
            uint256 timeDiffrence;
            if (current_stake.timeStaked == 12) {
                timeDiffrence = 2678400 * 12;
            } else if (current_stake.timeStaked == 6) {
                timeDiffrence = 2678400 * 6;
            } else if (current_stake.timeStaked == 3) {
                timeDiffrence = 2678400 * 3;
            } else if (current_stake.timeStaked == 1) {
                timeDiffrence = 2678400 * 1;
            } else if (current_stake.timeStaked == 2) {
                timeDiffrence = 120;
            }

            uint256 unstakeAmount = current_stake.amount;

            uint256 incentiveAmount;
            uint256 countIntrest;

            uint32 LCTApyPercent12M = 30;
            uint32 LCTApyPercent06M = 20;
            uint32 LCTApyPercent03M = 15;
            // for 1 mounth formula is 12.5 but there is not . in solidity
            // second thing in finding intrust i write 4 weeks but there is 4.3 weeks in one month
            // if we see these two things then the formula is actually the same
            uint32 LCTApyPercent01M = 12;

            if (timeDiffrence >= 52 weeks) {
                countIntrest = (unstakeAmount / 100) * LCTApyPercent12M;
                incentiveAmount = countIntrest + unstakeAmount;
            } else if (timeDiffrence >= 26 weeks) {
                countIntrest = ((unstakeAmount / 100) * LCTApyPercent06M) / 2;
                incentiveAmount = countIntrest + unstakeAmount;
            } else if (timeDiffrence >= 13 weeks) {
                countIntrest = ((unstakeAmount / 100) * LCTApyPercent03M) / 4;
                incentiveAmount = countIntrest + unstakeAmount;
            } else if (timeDiffrence >= 4 weeks) {
                countIntrest = ((unstakeAmount / 100) * LCTApyPercent01M) / 12;
                incentiveAmount = countIntrest + unstakeAmount;
            } else if (timeDiffrence >= 2 minutes) {
                countIntrest = 1000000000000000000;
                incentiveAmount = countIntrest + unstakeAmount;
            } else {
                incentiveAmount = unstakeAmount;
            }
            require(
                token.transfer(msg.sender, incentiveAmount),
                "Transfer failed."
            );
            stakingBalance[msg.sender] -= current_stake.amount;
        } else {
            // already withdrawed
            require(current_stake.claimable == true, "You already Withdrawed");
        }
    }

    function handleInvestInvestor(uint _value, address _sender) internal {
        liqudityProviders[_sender].push(S_liquidity(_value, block.timestamp));
    }

    function get_Investor(
        address _sender
    ) public view returns (S_liquidity[] memory) {
        return liqudityProviders[_sender];
    }

    receive() external payable {
        handleInvestInvestor(msg.value, msg.sender);
    }

    fallback() external payable {
        handleInvestInvestor(msg.value, msg.sender);
    }

    // at 5:17 he toled the way to use transact
}
