import SwiftUI
import Combine
import DynamicSDKSwift

// MARK: - ViewModel (holds subscriptions safely outside SwiftUI lifecycle)

private class WcGlobalListenerVM: ObservableObject {
  @Published var showProposal: WcSessionProposal?
  @Published var showRequest: WcSessionRequest?
  @Published var toastMessage: String?

  private var initialized = false
  private var initializing = false
  private var cancellables = Set<AnyCancellable>()

  init() {
    setupListeners()
  }

  func setupListeners() {
    guard let sdk = try? DynamicSDK.getInstance() else { return }
    let wc = sdk.walletConnect

    // Wait for auth token, then initialize WC (same as Flutter - no wcInitialized check)
    sdk.auth.tokenChanges
      .receive(on: DispatchQueue.main)
      .sink { [weak self] token in
        guard let self else { return }
        if let token, !token.isEmpty, !self.initialized, !self.initializing {
          self.initializing = true
          Task {
            do {
              try await wc.initialize()
              await MainActor.run {
                self.initialized = true
                self.initializing = false
                print("[WcGlobalListener] WC initialized successfully")
              }
            } catch {
              print("[WcGlobalListener] Failed to initialize WC: \(error)")
              await MainActor.run { self.initializing = false }
            }
          }
        } else if token == nil || token?.isEmpty == true {
          self.initialized = false
          self.initializing = false
        }
      }
      .store(in: &cancellables)

    // Listen for session proposals
    wc.onSessionProposal
      .receive(on: DispatchQueue.main)
      .sink { [weak self] proposal in
        print("[WcGlobalListener] onSessionProposal received: \(proposal.proposer.name)")
        self?.showProposal = proposal
      }
      .store(in: &cancellables)

    // Listen for session requests
    wc.onSessionRequest
      .receive(on: DispatchQueue.main)
      .sink { [weak self] request in
        print("[WcGlobalListener] onSessionRequest received: \(request.method)")
        self?.showRequest = request
      }
      .store(in: &cancellables)

    // Listen for session deletes
    wc.onSessionDelete
      .receive(on: DispatchQueue.main)
      .sink { [weak self] topic in
        print("[WcGlobalListener] onSessionDelete received: \(topic)")
        self?.toastMessage = "Session disconnected: \(String(topic.prefix(8)))..."
      }
      .store(in: &cancellables)
  }

  func approveProposal() {
    showProposal = nil
    Task {
      do {
        let wc = try DynamicSDK.getInstance().walletConnect
        try await wc.confirmPairing(confirm: true)
        await MainActor.run { toastMessage = "Session approved" }
      } catch {
        await MainActor.run { toastMessage = "Approval failed: \(error.localizedDescription)" }
      }
    }
  }

  func rejectProposal() {
    showProposal = nil
    Task { try? await DynamicSDK.getInstance().walletConnect.confirmPairing(confirm: false) }
  }

  func approveRequest(_ request: WcSessionRequest) {
    showRequest = nil
    Task {
      do {
        try await DynamicSDK.getInstance().walletConnect
          .respondSessionRequest(id: request.id, topic: request.topic, approved: true)
      } catch {
        await MainActor.run { toastMessage = "Request failed: \(error.localizedDescription)" }
      }
    }
  }

  func rejectRequest(_ request: WcSessionRequest) {
    showRequest = nil
    Task {
      try? await DynamicSDK.getInstance().walletConnect
        .respondSessionRequest(id: request.id, topic: request.topic, approved: false)
    }
  }
}

// MARK: - View

struct WcGlobalListener<Content: View>: View {
  let content: Content
  @StateObject private var vm = WcGlobalListenerVM()

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ZStack {
      content

      if let toast = vm.toastMessage {
        VStack {
          Spacer()
          Text(toast)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray2))
            .cornerRadius(8)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { vm.toastMessage = nil }
          }
        }
      }
    }
    .sheet(item: Binding(
      get: { vm.showProposal.map { IdentifiableProposal(proposal: $0) } },
      set: { if $0 == nil { vm.showProposal = nil } }
    )) { item in
      ProposalSheet(proposal: item.proposal, onApprove: {
        vm.approveProposal()
      }, onReject: {
        vm.rejectProposal()
      })
    }
    .sheet(item: Binding(
      get: { vm.showRequest.map { IdentifiableRequest(request: $0) } },
      set: { if $0 == nil { vm.showRequest = nil } }
    )) { item in
      RequestSheet(request: item.request, onApprove: {
        vm.approveRequest(item.request)
      }, onReject: {
        vm.rejectRequest(item.request)
      })
    }
  }
}

// MARK: - Identifiable wrappers for .sheet

private struct IdentifiableProposal: Identifiable {
  let id = UUID()
  let proposal: WcSessionProposal
}

private struct IdentifiableRequest: Identifiable {
  let id = UUID()
  let request: WcSessionRequest
}

// MARK: - Proposal Sheet

private struct ProposalSheet: View {
  let proposal: WcSessionProposal
  let onApprove: () -> Void
  let onReject: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text(proposal.proposer.name)
            .font(.title2)
            .fontWeight(.bold)

          if !proposal.proposer.description.isEmpty {
            Text(proposal.proposer.description)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }

          if !proposal.proposer.url.isEmpty {
            Text(proposal.proposer.url)
              .font(.caption)
              .foregroundColor(.blue)
          }

          Divider()

          if let ns = proposal.requiredNamespaces, !ns.isEmpty {
            Text("Required chains:")
              .font(.subheadline)
              .fontWeight(.semibold)
            ForEach(Array(ns.keys.sorted()), id: \.self) { key in
              if let namespace = ns[key] {
                Text("  \(key): \(namespace.chains.joined(separator: ", "))")
                  .font(.caption)
              }
            }
          }

          if let ns = proposal.optionalNamespaces, !ns.isEmpty {
            Text("Optional chains:")
              .font(.subheadline)
              .fontWeight(.semibold)
            ForEach(Array(ns.keys.sorted()), id: \.self) { key in
              if let namespace = ns[key] {
                Text("  \(key): \(namespace.chains.joined(separator: ", "))")
                  .font(.caption)
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle("Session Proposal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Reject", role: .destructive, action: onReject)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Approve", action: onApprove)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

// MARK: - Request Sheet

private struct RequestSheet: View {
  let request: WcSessionRequest
  let onApprove: () -> Void
  let onReject: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          LabeledContent("Method", value: request.method)
          LabeledContent("Chain", value: request.chainId)
          LabeledContent("Topic", value: "\(String(request.topic.prefix(12)))...")

          if let params = request.params {
            Divider()
            HStack {
              Text("Params:")
                .font(.subheadline)
                .fontWeight(.semibold)
              Spacer()
              Button {
                UIPasteboard.general.string = "\(params)"
              } label: {
                Image(systemName: "doc.on.doc")
                  .font(.caption)
              }
            }

            Text("\(params)")
              .font(.caption2)
              .monospaced()
              .padding(8)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color(.systemGray6))
              .cornerRadius(8)
          }
        }
        .padding()
      }
      .navigationTitle("Session Request")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Reject", role: .destructive, action: onReject)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Approve", action: onApprove)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
