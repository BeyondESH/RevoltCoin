// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/security/Pausable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/security/ReentrancyGuard.sol";

contract RevoltCoin is ERC20, Ownable, Pausable, ReentrancyGuard {
    // 最大供应量：1000 万枚（含 18 位小数）
    uint256 public constant MAX_SUPPLY = 10_000_000 * 10 ** 18;

    // 交易手续费百分比（初始为 2%）
    uint256 public transferFeePercent = 2;
    address public feeRecipient; // 收手续费的钱包地址
    mapping(address => bool) private _isExcludedFromFee;

    // 部署者地址（不可变）
    address public immutable deployer;

    // 事件
    event TransferFeePercentUpdated(uint256 previousFee, uint256 newFee);
    event FeeRecipientUpdated(address previousRecipient, address newRecipient);
    event ExcludeFromFee(address account);
    event IncludeInFee(address account);
    event OwnerUpdated(address indexed previousOwner, address indexed newOwner);
    event Airdrop(address indexed recipient, uint256 amount);

    constructor() ERC20("RevoltCoin", "Revolt") {
        // 记录合约部署者
        deployer = msg.sender;
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
        require(newRecipient != address(0), "RevoltCoin: invalid address");
        // 确保 feeRecipient 为 EOA，防止合约回调攻击
        require(
            newRecipient.code.length == 0,
            "RevoltCoin: fee recipient must be EOA"
        );
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

    /// @notice 安全转移合约所有权
    /// @param newOwner 新所有者地址
    function ownerTransfer(address newOwner) external onlyOwner {
        require(newOwner != address(0), "RevoltCoin: invalid new owner");
        emit OwnerUpdated(owner(), newOwner);
        _transferOwnership(newOwner);
    }

    /// @dev 重写内部转账逻辑，采用 Checks-Effects-Interactions 模式，防止重入
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override whenNotPaused {
        require(sender != address(0), "RevoltCoin: transfer from zero");
        require(recipient != address(0), "RevoltCoin: transfer to zero");
        if (
            transferFeePercent > 0 &&
            feeRecipient != address(0) &&
            !_isExcludedFromFee[sender] &&
            !_isExcludedFromFee[recipient]
        ) {
            uint256 fee = (amount * transferFeePercent) / 100;
            uint256 remaining = amount - fee;
            // 收取手续费
            super._transfer(sender, feeRecipient, fee);
            // 转账剩余
            super._transfer(sender, recipient, remaining);
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    /// @notice 暂停所有转账
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice 恢复转账
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev 在任何转账发生前检查暂停状态
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "RevoltCoin: token transfer while paused");
    }

    /// @notice 防重入安全的转账接口
    function transfer(
        address to,
        uint256 amount
    ) public override nonReentrant whenNotPaused returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override nonReentrant whenNotPaused returns (bool) {
        require(to != address(0), "RevoltCoin: transfer to zero");
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @notice 批量空投代币给指定地址
     * @param recipients 接收地址列表
     * @param amounts 每个地址对应的空投数量（最小单位）
     */
    function airdrop(address[] calldata recipients, uint256[] calldata amounts)
        external
        nonReentrant
        whenNotPaused
    {
        require(msg.sender == deployer, "RevoltCoin: only deployer can airdrop");
        require(recipients.length == amounts.length, "RevoltCoin: airdrop arrays mismatch");
        uint256 total;
        // 计算总空投量
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        // 确保不超过最大供应量
        require(totalSupply() + total <= MAX_SUPPLY, "RevoltCoin: exceeds max supply");
        // 分发空投
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit Airdrop(recipients[i], amounts[i]);
        }
    }
}
