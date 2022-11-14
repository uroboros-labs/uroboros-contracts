// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./libraries/Fee.sol";

import "hardhat/console.sol";

contract ERC20TransferFee is Ownable, IERC20, IERC20Metadata {
	using Fee for uint256;

	string public name;
	string public symbol;
	uint8 public constant decimals = 18;

	uint256 public totalSupply;
	mapping(address => uint256) public balanceOf;
	mapping(address => mapping(address => uint256)) public allowance;

	mapping(address => uint256) public transferToFee;
	mapping(address => uint256) public transferFromFee;

	event TransferToFeeUpdated(address indexed to, uint256 fee);
	event TransferFromFeeUpdated(address indexed from, uint256 fee);

	constructor(
		string memory _name,
		string memory _symbol,
		uint256 initalSupply
	) {
		name = _name;
		symbol = _symbol;
		totalSupply = initalSupply;
		_mint(_msgSender(), initalSupply);
	}

	function setTransferToFee(address to, uint256 fee) external onlyOwner {
		transferToFee[to] = fee;
		emit TransferFromFeeUpdated(to, fee);
	}

	function setTransferFromFee(address from, uint256 fee) external onlyOwner {
		transferFromFee[from] = fee;
		emit TransferFromFeeUpdated(from, fee);
	}

	function mint(address to, uint256 amount) internal onlyOwner {
		_mint(to, amount);
	}

	function _mint(address to, uint256 amount) internal {
		balanceOf[to] += amount;
		totalSupply += amount;
		emit Transfer(address(0x0), to, amount);
	}

	function _transfer(
		address owner,
		address to,
		uint256 amount
	) internal {
		require(balanceOf[owner] >= amount, "ERC20TransferFee: insufficient balance");
		uint256 _transferFromFee = transferFromFee[owner];
		uint256 _transferToFee = transferToFee[to];
		unchecked {
			balanceOf[owner] -= amount;
		}
		uint256 totalFee = _transferFromFee.mul(_transferToFee);
		console.log("totalFee: %s", totalFee);
		amount = totalFee.getAmountLessFee(amount);
		console.log("amountLessFee: %s", amount);
		balanceOf[to] += amount;
		emit Transfer(owner, to, amount);
	}

	function transfer(address to, uint256 amount) external returns (bool) {
		_transfer(msg.sender, to, amount);
		return true;
	}

	function transferFrom(
		address from,
		address to,
		uint256 amount
	) external returns (bool) {
		require(allowance[from][msg.sender] >= amount, "ERC20TransferFee: insufficient allowance");
		unchecked {
			allowance[from][msg.sender] -= amount;
		}
		_transfer(from, to, amount);
		return true;
	}

	function approve(address spender, uint256 amount) external returns (bool) {
		allowance[msg.sender][spender] = amount;
		emit Approval(msg.sender, spender, amount);
		return true;
	}
}
