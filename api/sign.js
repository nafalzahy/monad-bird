const { ethers } = require("ethers");
const Core = require("../game-core.js");

module.exports = async (req, res) => {
  try {
    if (req.method !== "POST") return res.status(405).json({ error: "Gunakan POST" });
    const { player, bossId, seed, inputs } = req.body || {};

    if (!ethers.isAddress(player)) return res.status(400).json({ error: "Alamat wallet tidak valid" });
    if (!Number.isInteger(bossId) || bossId < 1 || bossId > 4) return res.status(400).json({ error: "Boss tidak valid" });
    if (!Number.isInteger(seed)) return res.status(400).json({ error: "Seed tidak valid" });
    if (!Array.isArray(inputs) || inputs.length > 6000 || !inputs.every((n) => Number.isInteger(n) && n >= 0))
      return res.status(400).json({ error: "Data input tidak valid" });

    // putar ulang permainan di server
    const r = Core.simulate(bossId, seed, inputs);
    if (!r.won) return res.status(400).json({ error: "Replay tidak menunjukkan kemenangan" });

    const hash = ethers.solidityPackedKeccak256(
      ["address", "uint256", "address", "uint8", "uint256"],
      [process.env.CONTRACT_ADDRESS, 10143, player, bossId, r.score]
    );
    const wallet = new ethers.Wallet(process.env.SIGNER_KEY);
    const signature = await wallet.signMessage(ethers.getBytes(hash));
    return res.status(200).json({ score: r.score, signature });
  } catch (e) {
    return res.status(500).json({ error: "Server error: " + e.message });
  }
};