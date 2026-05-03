# Hiero SDK for Dart

A PoC of Hiero SDK for the Dart programming language.

## Getting Started

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  hiero_sdk_dart:
    path: ./ # appropriate git reference
```

Then run:

```bash
dart pub get
```

## Usage

### Prerequisites

To run examples localy:

Create a `.env` file in your project root with your operator credentials:

> [!IMPORTANT]
> ### Only ED25519 keys are supported
>
> Before entering the operator id and key make sure you have ED25519 account (default is ECDSA not ED25519)

```env
OPERATOR_ID=0.0.1234
OPERATOR_KEY=302e020100300506032b657004220420...
HEDERA_NETWORK=previewnet
```

create protobufs by running:
```
python3 generate_proto.py
```

run the account creation example:
```
dart example/account/account_create_transaction.dart
```

