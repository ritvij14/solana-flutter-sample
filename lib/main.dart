import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late AuthorizationResult? _result;
  final solanaClient = SolanaClient(
    rpcUrl: Uri.parse("https://api.devnet.solana.com"),
    websocketUrl: Uri.parse("wss://api.devnet.solana.com"),
  );
  final int lamportsPerSol = 1000000000;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Solana Flutter Example"),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  /// step 1
                  final localScenario = await LocalAssociationScenario.create();

                  /// step 2
                  localScenario.startActivityForResult(null).ignore();

                  /// step 3
                  final client = await localScenario.start();

                  /// step 4
                  final result = await client.authorize(
                    identityUri: Uri.parse('https://solana.com'),
                    iconUri: Uri.parse('favicon.ico'),
                    identityName: 'Solana',
                    cluster: 'devnet',
                  );

                  /// step 5
                  localScenario.close();

                  setState(() {
                    _result = result;
                  });
                },
                child: const Text("Authorize"),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await solanaClient.requestAirdrop(
                      /// Ed25519HDPublicKey is the main class that represents public
                      /// key in the solana dart library
                      address: Ed25519HDPublicKey(
                        _result!.publicKey.toList(),
                      ),
                      lamports: 1 * lamportsPerSol,
                    );
                  } catch (e) {
                    print("$e");
                  }
                },
                child: const Text("Request Airdrop"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final localScenario = await LocalAssociationScenario.create();
                  localScenario.startActivityForResult(null).ignore();
                  final client = await localScenario.start();
                  final reAuth = await client.reauthorize(
                    identityUri: Uri.parse('https://solana.com'),
                    iconUri: Uri.parse('favicon.ico'),
                    identityName: 'Solana',
                    authToken: _result!.authToken,
                  );

                  if (reAuth != null) {
                    /// create Memo Program Transaction
                    final instruction = MemoInstruction(signers: [
                      Ed25519HDPublicKey(
                        _result!.publicKey.toList(),
                      ),
                    ], memo: 'Example memo');

                    final signature = Signature(
                      List.filled(64, 0),
                      publicKey: Ed25519HDPublicKey(
                        _result!.publicKey.toList(),
                      ),
                    );

                    final blockhash = await solanaClient.rpcClient
                        .getLatestBlockhash()
                        .then((it) => it.value.blockhash);

                    final txn = SignedTx(
                      signatures: [signature],
                      compiledMessage: Message.only(instruction).compile(
                        recentBlockhash: blockhash,
                        feePayer: Ed25519HDPublicKey(
                          _result!.publicKey.toList(),
                        ),
                      ),
                    );

                    final result = await client.signAndSendTransactions(
                      transactions: [
                        Uint8List.fromList(txn.toByteArray().toList())
                      ],
                    );

                    await localScenario.close();

                    print(
                      "TRANSACTION SIGNATURE: https://solscan.io/tx/${base58encode(result.signatures[0])}?cluster=devnet",
                    );
                  }
                },
                child: const Text("Generate and Sign Transactions"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
