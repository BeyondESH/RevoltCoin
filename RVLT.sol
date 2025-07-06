// SPDX-License-Identifier: MIT
// 指定许可证协议，方便开源平台识别（MIT 是最宽松的开源协议之一）
pragma solidity ^0.8.0;

// 指定 Solidity 编译器版本，^0.8.0 表示兼容 0.8.0 及以上的小版本，但不包括 0.9.x

// 合约声明
contract RVLT {
    // ----------- 🔹1. 基本信息部分（Token Metadata）------------

    string public name = "RevoltCoin"; // 代币名称，可被外部读取
    string public symbol = "RVLT"; // 代币符号（如 ETH、USDT）
    uint8 public decimals = 18; // 精度，小数点位数，通常为 18 位
    uint256 public totalSupply; // 总供应量（总发行量）

    // ----------- 🔹2. 核心状态映射（Token 数据存储）------------

    mapping(address => uint256) public balanceOf;
    // 存储每个地址对应的代币余额，相当于地址 => 数字 的映射表

    mapping(address => mapping(address => uint256)) public allowance;
    // 授权额度：例如 Alice 授权给 Uniswap 1000 MTK 让它自动代扣

    // ----------- 🔹3. 事件（Event 日志）------------

    event Transfer(address indexed from, address indexed to, uint256 value);
    // 当发生转账时，触发这个事件，便于前端监听或区块浏览器显示

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // 当某个用户授权另一个地址可花费代币时触发

    // ----------- 🔹4. 构造函数：部署时运行一次，初始化合约------------

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply * (10 ** uint256(decimals));
        // 将初始供应量乘以 10^18（因为我们设置了 decimals = 18）

        balanceOf[msg.sender] = totalSupply;
        // 将所有初始代币分配给合约部署者本人（msg.sender）

        emit Transfer(address(0), msg.sender, totalSupply);
        // 从地址0转入，表示是铸造代币行为，便于链上查询
    }

    // ----------- 🔹5. 转账函数（最基本的 Token 功能）------------

    function transfer(
        address _to,
        uint256 _value
    ) public returns (bool success) {
        // msg.sender 是发起交易的人
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        // 如果余额不足，抛出异常，交易失败并回滚

        balanceOf[msg.sender] -= _value; // 扣除转出账户余额
        balanceOf[_to] += _value; // 增加接收账户余额

        emit Transfer(msg.sender, _to, _value); // 发出 Transfer 事件
        return true;
    }

    // ----------- 🔹6. 授权函数（approve）------------

    function approve(
        address _spender,
        uint256 _value
    ) public returns (bool success) {
        // 授权某个地址可以代表你花费一定数量的代币
        allowance[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); // 发出授权事件
        return true;
    }

    // ----------- 🔹7. 授权转账函数（transferFrom）------------

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        // 通常由第三方合约调用，例如 Uniswap 合约来执行交易

        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Not allowed");

        balanceOf[_from] -= _value; // 扣除_from余额
        balanceOf[_to] += _value; // 增加_to余额
        allowance[_from][msg.sender] -= _value; // 扣除授权额度

        emit Transfer(_from, _to, _value); // 触发转账事件
        return true;
    }
}
