//
//  ContentView.swift
//  llama-stack-ios
//
//  Created by Vishrut Jha on 12/17/24.
//

import SwiftUI
import LlamaStackClient

struct Message: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.isUser == rhs.isUser
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputMessage: String = ""
    private let inference: RemoteInference
    private let config = Config.shared
    
    init() {
        inference = RemoteInference(url: config.inferenceURL)
    }
    
    func sendMessage() async {
        guard !inputMessage.isEmpty else { return }
        let messageText = inputMessage
        let userMessage = Message(content: messageText, isUser: true)
        
        messages.append(userMessage)
        inputMessage = ""
        
        do {
            var assistantResponse = ""
            for try await chunk in try await inference.chatCompletion(
                request: Components.Schemas.ChatCompletionRequest(
                    messages: [
                        .SystemMessage(Components.Schemas.SystemMessage(
                            content: .case1(config.systemMessage),
                            role: .system
                        )),
                        .UserMessage(Components.Schemas.UserMessage(
                            content: .case1(messageText),
                            role: .user)
                        )
                    ],
                    model_id: config.modelId,
                    stream: true)
            ) {
                switch chunk.event.delta {
                case .case1(let text):
                    assistantResponse += text
                    if let lastMessage = messages.last, !lastMessage.isUser {
                        messages[messages.count - 1] = Message(
                            content: assistantResponse,
                            isUser: false
                        )
                    } else {
                        messages.append(Message(
                            content: assistantResponse,
                            isUser: false
                        ))
                    }
                case .ToolCallDelta(_):
                    break
                }
            }
        } catch {
            print("Error: \(error)")
            messages.append(Message(
                content: "Error: Unable to get response from the server",
                isUser: false
            ))
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack {
                TextField("Type a message...", text: $viewModel.inputMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .cornerRadius(15)
                    .shadow(radius: 2, x: 0, y: 0)
                    .padding(.horizontal)
                    .onSubmit {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                
                Button(action: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                }
                .disabled(viewModel.inputMessage.isEmpty)
                .padding(.trailing)
            }
            .padding(.vertical)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(16)
            
            if !message.isUser { Spacer() }
        }
    }
}

#Preview {
    ContentView()
}
