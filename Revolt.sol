// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 使用 GitHub 原始 URL 导入 OpenZeppelin 合约
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/security/Pausable.sol";

contract RevoltCoin is ERC20, Ownable, Pausable {
    // 最大供应量：1000 万枚（含 18 位小数）
    uint256 public constant MAX_SUPPLY = 10_000_000 * 10 ** 18;

    // 交易手续费百分比（初始为 2%）
    uint256 public transferFeePercent = 2;
    address public feeRecipient; // 收手续费的钱包地址
    mapping(address => bool) private _isExcludedFromFee;

    // 事件
    event TransferFeePercentUpdated(uint256 previousFee, uint256 newFee);
    event FeeRecipientUpdated(address previousRecipient, address newRecipient);
    event ExcludeFromFee(address account);
    event IncludeInFee(address account);

    constructor() ERC20("RevoltCoin", "Revolt") {
        // 将部署者设为手续费接收者
        feeRecipient = msg.sender;
        // 默认排除部署者和手续费接收者
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[feeRecipient] = true;

        // 初始发行 1,000,000 枚代币，保留 900,000 枚，手动添加流动性 100,000 枚
        uint256 initialSupply = 1_000_000 * 10 ** decimals();
        _mint(msg.sender, initialSupply);
    }

    // 增发函数，仅 owner 可调用，受 MAX_SUPPLY 限制
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    // 修改手续费比例（最大不得超过 10%）
    function setTransferFeePercent(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Fee too high");
        uint256 previous = transferFeePercent;
        transferFeePercent = newFee;
        emit TransferFeePercentUpdated(previous, newFee);
    }

    // 修改手续费接收地址
    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid address");
        address previous = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(previous, newRecipient);
    }

    // 手续费豁免
    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
        emit ExcludeFromFee(account);
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
        emit IncludeInFee(account);
    }

    // 重写 transfer 以添加手续费逻辑
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override whenNotPaused {
        if (
            transferFeePercent > 0 &&
            feeRecipient != address(0) &&
            !_isExcludedFromFee[sender] &&
            !_isExcludedFromFee[recipient]
        ) {
            uint256 fee = (amount * transferFeePercent) / 100;
            uint256 remaining = amount - fee;

            super._transfer(sender, feeRecipient, fee);
            super._transfer(sender, recipient, remaining);
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    // 销毁函数（可选）
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // 紧急停止
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "Token transfer while paused");
    }
}
