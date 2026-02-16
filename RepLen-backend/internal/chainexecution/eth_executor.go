package chainexecution

import (
	"context"
	//"crypto/ecdsa"
	"errors"
	"log"
	"math/big"
	"strings"

	"github.com/Tanya0816/RepLen/RepLen-backend/internal/intent"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

type EthExecutor struct {
	client      *ethclient.Client
	auth        *bind.TransactOpts
	poolManager common.Address
}

/*
========================================
CONSTRUCTOR
========================================
*/

func NewEthExecutor(
	rpcURL string,
	privateKeyHex string,
	poolManagerAddr string,
	chainID *big.Int,
) (*EthExecutor, error) {

	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		return nil, err
	}

	privateKey, err := crypto.HexToECDSA(privateKeyHex)
	if err != nil {
		return nil, err
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		return nil, err
	}

	auth.Context = context.Background()

	log.Println("[RPC] Connected to Ethereum RPC")

	return &EthExecutor{
		client:      client,
		auth:        auth,
		poolManager: common.HexToAddress(poolManagerAddr),
	}, nil
}

/*
========================================
INTENT ROUTER
========================================
*/

func (e *EthExecutor) ExecuteIntent(i intent.LenIntent) error {

	switch i.Action {

	case intent.AddLiquidity:
		return e.addLiquidity(i)

	case intent.RemoveLiquidity:
		return e.removeLiquidity(i)

	case intent.Rebalance:
		return e.rebalance(i)

	default:
		return errors.New("unknown action")
	}
}

/*
========================================
UNISWAP V4 MODIFY LIQUIDITY
========================================
*/

const PoolManagerABI = `[
	{
		"inputs": [
			{
				"components": [
					{"internalType": "bytes32", "name": "poolId", "type": "bytes32"},
					{"internalType": "int24", "name": "tickLower", "type": "int24"},
					{"internalType": "int24", "name": "tickUpper", "type": "int24"},
					{"internalType": "int128", "name": "liquidityDelta", "type": "int128"}
				],
				"internalType": "struct ModifyLiquidityParams",
				"name": "params",
				"type": "tuple"
			},
			{"internalType": "bytes", "name": "hookData", "type": "bytes"}
		],
		"name": "modifyLiquidity",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	}
]`

func (e *EthExecutor) addLiquidity(i intent.LenIntent) error {

	parsedABI, err := abi.JSON(strings.NewReader(PoolManagerABI))
	if err != nil {
		return err
	}

	liquidityDelta := big.NewInt(int64(i.Amount))

	params := struct {
		PoolId         [32]byte
		TickLower      int32
		TickUpper      int32
		LiquidityDelta *big.Int
	}{
		PoolId:         common.HexToHash(i.PoolID),
		TickLower:      -600,
		TickUpper:      600,
		LiquidityDelta: liquidityDelta,
	}

	input, err := parsedABI.Pack(
		"modifyLiquidity",
		params,
		[]byte{}, // hookData (empty for now)
	)
	if err != nil {
		return err
	}

	nonce, err := e.client.PendingNonceAt(context.Background(), e.auth.From)
	if err != nil {
		return err
	}

	gasPrice, err := e.client.SuggestGasPrice(context.Background())
	if err != nil {
		return err
	}

	tx := types.NewTransaction(
		nonce,
		e.poolManager,
		big.NewInt(0),
		500000, // gas limit (adjust later)
		gasPrice,
		input,
	)

	signedTx, err := e.auth.Signer(e.auth.From, tx)
	if err != nil {
		return err
	}

	err = e.client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		return err
	}

	log.Printf("[TX SENT] addLiquidity → %s", signedTx.Hash().Hex())
	return nil
}

/*
========================================
REMOVE / REBALANCE (stub for now)
========================================
*/

func (e *EthExecutor) removeLiquidity(i intent.LenIntent) error {
	log.Println("[ETH] removeLiquidity not implemented yet")
	return nil
}

func (e *EthExecutor) rebalance(i intent.LenIntent) error {
	log.Println("[ETH] rebalance not implemented yet")
	return nil
}
