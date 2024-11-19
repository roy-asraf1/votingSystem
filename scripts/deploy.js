const hre = require("hardhat");

async function main() {
  const MANAGER = 1;  // Role.Manager
  const CUSTOMER = 2; // Role.Customer

  // Get the contract to deploy
  const VotingSystem = await hre.ethers.getContractFactory("VotingSystem");

  // Deploy the contract
  const votingSystem = await VotingSystem.deploy();

  // Wait for the deployment transaction to be mined
  await votingSystem.deployed();
  console.log("VotingSystem deployed to:", votingSystem.address);

  // Add initial users (example)
  try {
    const tx1 = await votingSystem.addUser(
      "0x42c4FCAefAaeA2af28F7F6e2f16e728b6E081A98",
      "Roni Manager",
      MANAGER
    );
    // Wait for the transaction to be confirmed
    await tx1.wait();
    console.log("User added: Roni Manager");
  } catch (error) {
    // If the user already exists, log a warning instead of an error
    if (error.message.includes("User already exists")) {
      console.warn("Warning: Roni Manager already exists.");
    } else {
      console.error("Error adding Roni Manager:", error);
    }
  }

  try {
    const tx2 = await votingSystem.addUser(
      "0x3d804410dAA31f4E74dEB8fE0539E90703E6A526",  // Replace with a valid address
      "Bob Customer",
      CUSTOMER // Role.Customer
    );
    // Wait for the transaction to be confirmed
    await tx2.wait();
    console.log("User added: Bob Customer");
  } catch (error) {
    // If the user already exists, log a warning instead of an error
    if (error.message.includes("User already exists")) {
      console.warn("Warning: Bob Customer already exists.");
    } else {
      console.error("Error adding Bob Customer:", error);
    }
  }

  const userAddresses = await votingSystem.getAllUsers();
  console.log("User Addresses:", userAddresses);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });