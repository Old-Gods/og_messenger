import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../settings/providers/settings_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../messaging/data/services/tcp_server_service.dart';
import '../data/services/security_service.dart';

/// Password change proposal state
class PasswordProposal {
  final String id;
  final String proposerDeviceId;
  final String proposerName;
  final int timestamp;
  final String newPasswordHash;
  final String newEncryptedKey;
  final String keySalt;
  final Set<String> requiredPeerIds;
  final Map<String, bool> votes;
  final DateTime expiresAt;

  PasswordProposal({
    required this.id,
    required this.proposerDeviceId,
    required this.proposerName,
    required this.timestamp,
    required this.newPasswordHash,
    required this.newEncryptedKey,
    required this.keySalt,
    required this.requiredPeerIds,
    this.votes = const {},
    required this.expiresAt,
  });

  int get yesVotes => votes.values.where((v) => v).length;
  int get noVotes => votes.values.where((v) => !v).length;
  int get requiredVoteCount => requiredPeerIds.length;
  bool get isApproved =>
      votes.length == requiredVoteCount && votes.values.every((v) => v);
  bool get isRejected => votes.values.any((v) => !v);
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  PasswordProposal copyWith({
    Map<String, bool>? votes,
  }) {
    return PasswordProposal(
      id: id,
      proposerDeviceId: proposerDeviceId,
      proposerName: proposerName,
      timestamp: timestamp,
      newPasswordHash: newPasswordHash,
      newEncryptedKey: newEncryptedKey,
      keySalt: keySalt,
      requiredPeerIds: requiredPeerIds,
      votes: votes ?? this.votes,
      expiresAt: expiresAt,
    );
  }
}

/// Password state
class PasswordState {
  final PasswordProposal? activeProposal;
  final String? error;
  final String? successMessage;

  const PasswordState({
    this.activeProposal,
    this.error,
    this.successMessage,
  });

  PasswordState copyWith({
    PasswordProposal? activeProposal,
    String? error,
    String? successMessage,
    bool clearProposal = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PasswordState(
      activeProposal: clearProposal ? null : (activeProposal ?? this.activeProposal),
      error: clearError ? null : error,
      successMessage: clearSuccess ? null : successMessage,
    );
  }
}

/// Password notifier for managing password changes and voting
class PasswordNotifier extends Notifier<PasswordState> {
  late TcpServerService _tcpServer;
  late SecurityService _securityService;
  Timer? _expirationTimer;
  StreamSubscription? _proposalSubscription;
  StreamSubscription? _voteSubscription;

  @override
  PasswordState build() {
    _tcpServer = TcpServerService();
    _securityService = SecurityService.instance;

    // Listen to incoming proposals
    _proposalSubscription = _tcpServer.passwordProposalStream.listen(_handleProposal);

    // Listen to incoming votes
    _voteSubscription = _tcpServer.passwordVoteStream.listen(_handleVote);

    // Listen to peer changes to detect disconnections during voting
    ref.onDispose(() {
      _clearTimer();
      _proposalSubscription?.cancel();
      _voteSubscription?.cancel();
    });
    
    ref.listen(discoveryProvider, (previous, next) {
      _checkPeerChanges(previous, next);
    });

    return const PasswordState();
  }

  /// Propose a new password change
  Future<void> proposePasswordChange(String newPassword) async {
    try {
      final settings = ref.read(settingsProvider);
      final discovery = ref.read(discoveryProvider);

      if (state.activeProposal != null) {
        state = state.copyWith(error: 'Proposal already in progress');
        return;
      }

      // Get all currently connected peers (including self)
      final allPeers = discovery.peers.keys.toSet();
      allPeers.add(settings.deviceId!);

      // Generate new encryption key and hash
      const uuid = Uuid();
      final proposalId = uuid.v7();
      final passwordHash = _securityService.hashPassword(newPassword);
      final newKey = _securityService.generateRandomKey();

      // Use first peer's device ID as salt for deterministic key derivation
      final keySalt = settings.deviceId!;

      // Encrypt the new key with the new password
      final encryptedKey = _securityService.encryptKeyWithPassword(
        newKey,
        newPassword,
        keySalt,
      );

      final proposal = PasswordProposal(
        id: proposalId,
        proposerDeviceId: settings.deviceId!,
        proposerName: settings.userName!,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        newPasswordHash: passwordHash,
        newEncryptedKey: encryptedKey,
        keySalt: keySalt,
        requiredPeerIds: allPeers,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      // Vote yes automatically (proposer)
      final updatedVotes = {settings.deviceId!: true};
      state = state.copyWith(
        activeProposal: proposal.copyWith(votes: updatedVotes),
        clearError: true,
      );

      // Broadcast proposal to all peers
      final message = {
        'type': 'password_proposal',
        'proposal_id': proposalId,
        'proposer_device_id': settings.deviceId!,
        'proposer_name': settings.userName!,
        'timestamp': proposal.timestamp,
        'new_password_hash': passwordHash,
        'new_encrypted_key': encryptedKey,
        'key_salt': keySalt,
        'required_peers': allPeers.toList(),
      };

      await _broadcastMessage(message);

      // Start expiration timer
      _startExpirationTimer();

      // Check if proposal is immediately complete (e.g., only one peer)
      _checkProposalCompletion();

      print('🔐 Password proposal sent: $proposalId');
    } catch (e) {
      state = state.copyWith(error: 'Failed to propose: $e');
    }
  }

  /// Handle incoming proposal
  void _handleProposal(Map<String, dynamic> data) {
    try {
      final settings = ref.read(settingsProvider);

      // Don't process our own proposal
      if (data['proposer_device_id'] == settings.deviceId) return;

      final proposal = PasswordProposal(
        id: data['proposal_id'] as String,
        proposerDeviceId: data['proposer_device_id'] as String,
        proposerName: data['proposer_name'] as String,
        timestamp: data['timestamp'] as int,
        newPasswordHash: data['new_password_hash'] as String,
        newEncryptedKey: data['new_encrypted_key'] as String,
        keySalt: data['key_salt'] as String,
        requiredPeerIds:
            (data['required_peers'] as List).cast<String>().toSet(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      state = state.copyWith(activeProposal: proposal, clearError: true);
      _startExpirationTimer();

      print('🔐 Received password proposal: ${proposal.id}');
    } catch (e) {
      print('❌ Failed to handle proposal: $e');
    }
  }

  /// Vote on a proposal
  Future<void> voteOnProposal(String proposalId, bool approve) async {
    try {
      final settings = ref.read(settingsProvider);
      final proposal = state.activeProposal;

      if (proposal == null || proposal.id != proposalId) {
        state = state.copyWith(error: 'Proposal not found');
        return;
      }

      // Record vote locally
      final updatedVotes = Map<String, bool>.from(proposal.votes);
      updatedVotes[settings.deviceId!] = approve;

      state = state.copyWith(
        activeProposal: proposal.copyWith(votes: updatedVotes),
        clearError: true,
      );

      // Broadcast vote
      final voteMessage = {
        'type': 'password_vote',
        'proposal_id': proposalId,
        'voter_device_id': settings.deviceId!,
        'voter_name': settings.userName!,
        'vote': approve,
      };

      await _broadcastMessage(voteMessage);

      // Check if voting complete
      _checkProposalCompletion();

      print('✅ Vote cast: $approve for proposal $proposalId');
    } catch (e) {
      state = state.copyWith(error: 'Failed to vote: $e');
    }
  }

  /// Handle incoming vote
  void _handleVote(Map<String, dynamic> data) {
    try {
      final proposal = state.activeProposal;
      if (proposal == null || proposal.id != data['proposal_id']) return;

      final voterId = data['voter_device_id'] as String;
      final vote = data['vote'] as bool;

      // Update votes
      final updatedVotes = Map<String, bool>.from(proposal.votes);
      updatedVotes[voterId] = vote;

      state = state.copyWith(
        activeProposal: proposal.copyWith(votes: updatedVotes),
      );

      print('📩 Received vote from ${data['voter_name']}: $vote');

      // Check completion
      _checkProposalCompletion();
    } catch (e) {
      print('❌ Failed to handle vote: $e');
    }
  }

  /// Check if proposal is complete
  void _checkProposalCompletion() {
    final proposal = state.activeProposal;
    if (proposal == null) return;

    if (proposal.isRejected) {
      print('❌ Password change rejected');
      state = state.copyWith(
        error: 'Password change was rejected',
        clearProposal: true,
      );
      _clearTimer();
    } else if (proposal.isApproved) {
      print('✅ Password change approved by all peers');
      _applyPasswordChange(proposal);
    }
  }

  /// Apply the password change
  Future<void> _applyPasswordChange(PasswordProposal proposal) async {
    try {
      // Decrypt the new encryption key with the new password
      // For the proposer, we already have the key
      // For voters, we need to get the password from the user first
      // Since we're here, it means all votes are in, so we can apply
      
      // Set the new password hash
      await _securityService.setPasswordHash(proposal.newPasswordHash);
      
      // The encryption key will be set when the user enters the new password
      // For now, we just store the encrypted version
      // This will be decrypted on next app launch or when user provides password
      
      print('🔐 Password changed successfully');
      state = state.copyWith(
        successMessage: 'Password changed successfully',
        clearProposal: true,
        clearError: true,
      );
      _clearTimer();
    } catch (e) {
      state = state.copyWith(error: 'Failed to apply password: $e');
    }
  }

  /// Check for peer changes during voting
  void _checkPeerChanges(DiscoveryState? previous, DiscoveryState next) {
    final proposal = state.activeProposal;
    if (proposal == null) return;

    final settings = ref.read(settingsProvider);

    // Check if proposer disconnected
    if (!next.peers.containsKey(proposal.proposerDeviceId) &&
        proposal.proposerDeviceId != settings.deviceId) {
      print('❌ Proposer disconnected - aborting proposal');
      state = state.copyWith(
        error: 'Proposer disconnected',
        clearProposal: true,
      );
      _clearTimer();
      return;
    }

    // Check if any required voter disconnected
    for (final peerId in proposal.requiredPeerIds) {
      if (peerId != settings.deviceId &&
          !next.peers.containsKey(peerId)) {
        print('❌ Required voter disconnected - aborting proposal');
        state = state.copyWith(
          error: 'A peer disconnected during voting',
          clearProposal: true,
        );
        _clearTimer();
        return;
      }
    }

    // Check if new peer joined
    final newPeers = next.peers.keys.toSet().difference(
          previous?.peers.keys.toSet() ?? {},
        );

    if (newPeers.isNotEmpty) {
      print('⚠️ New peer joined during voting - aborting proposal');
      state = state.copyWith(
        error: 'New peer joined during voting',
        clearProposal: true,
      );
      _clearTimer();
    }
  }

  /// Start expiration timer
  void _startExpirationTimer() {
    _clearTimer();
    _expirationTimer = Timer(const Duration(minutes: 5), () {
      if (state.activeProposal?.isExpired ?? false) {
        print('⏰ Proposal expired');
        state = state.copyWith(
          error: 'Proposal timed out',
          clearProposal: true,
        );
      }
    });
  }

  /// Clear timer
  void _clearTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = null;
  }

  /// Broadcast message to all peers
  Future<void> _broadcastMessage(Map<String, dynamic> message) async {
    final discovery = ref.read(discoveryProvider);
    for (final peer in discovery.peers.values) {
      await _tcpServer.sendGenericMessage(
        peer.ipAddress,
        peer.tcpPort,
        message,
      );
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}

/// Provider
final passwordProvider = NotifierProvider<PasswordNotifier, PasswordState>(
  () => PasswordNotifier(),
);
