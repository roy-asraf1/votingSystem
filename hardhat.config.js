require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.18",
  networks: {
    ganache: {
      url: "http://127.0.0.1:7545",
      accounts: ["915b5120d10a99c7e48e46df6e35797984c2c2686bbf5de9d8098980c428c2fe"],
    },
  },
};