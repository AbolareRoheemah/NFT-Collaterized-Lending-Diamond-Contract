// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { LibDiamond } from "../libraries/LibDiamond.sol";
contract ERC20Facet {

    function balanceOfERC20(address account) public  virtual returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds._balances[account];
    }
    function transfer(address to, uint256 value) public returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public  virtual returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds._allowances[owner][spender];
    }

    function approveERC20(address spender, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function transferERC20From(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert LibDiamond.ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert LibDiamond.ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            ds._totalSupply += value;
        } else {
            uint256 fromBalance = ds._balances[from];
            if (fromBalance < value) {
                revert LibDiamond.ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                ds._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                ds._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                ds._balances[to] += value;
            }
        }

        emit LibDiamond.Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert LibDiamond.ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function mint(address account, uint256 value) public returns (bool) {
        // address owner = msg.sender;
        _mint(account, value);
        return true;
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert LibDiamond.ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (owner == address(0)) {
            revert LibDiamond.ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert LibDiamond.ERC20InvalidSpender(address(0));
        }
        ds._allowances[owner][spender] = value;
        if (emitEvent) {
            emit LibDiamond.Approval(owner, spender, value);
        }
    }


    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert LibDiamond.ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}