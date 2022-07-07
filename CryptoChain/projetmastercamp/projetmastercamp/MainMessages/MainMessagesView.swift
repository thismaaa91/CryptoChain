//
//  MainMessagesView.swift
//  projetmastercamp
//
//  Created by Vincent Retkowsky on 27/06/2022.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseFirestoreSwift
import CryptoKit

struct RecentMessage: Codable, Identifiable{
//    var id: String{documentId}
    @DocumentID var id: String?
//    let documentId: String
    let profileImageUrl: String
    let text, email: String
    let fromId, toId: String
    let timestamp: Date
//    init(documentId: String, data:[String: Any]){
//        self.documentId = documentId
//        self.fromId = data["fromId"] as? String ?? ""
//        self.toId = data["toId"] as? String ?? ""
//        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
//        self.text = data["text"] as? String ?? ""
//        self.email = data["email"] as? String ?? ""
//        self.timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
//    }
    var username: String{
        email.components(separatedBy: "@").first ?? ""
    }
    var timeAgo: String{
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}


class MainMessagesViewModel: ObservableObject{
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isUserCurrentlyLoggedOut = false

    init(){
        DispatchQueue.main.async {
            self.isUserCurrentlyLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurentUser()
        fetchRecentMessages()
    }
    
    @Published var recentMessages = [RecentMessage]()
    private var firestoreListener: ListenerRegistration?
    func fetchRecentMessages(){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {return}
        firestoreListener?.remove()
        self.recentMessages.removeAll()
        firestoreListener = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error{
                    self.errorMessage = "ERREUR: \(error)"
                    print(error)
                    return
                }
                querySnapshot?.documentChanges.forEach({ change in
                    let docId = change.document.documentID
                    if let index = self.recentMessages.firstIndex(where: { rm in
                        return rm.id == docId
                    }){
                        self.recentMessages.remove(at: index)
                    }
                    do{
                        let rm = try change.document.data(as: RecentMessage.self)
                        self.recentMessages.insert(rm, at: 0)
                    }catch{
                        print(error)
                    }
//                    self.recentMessages.insert(.init(documentId: docId, data: change.document.data()), at: 0)
                 //   self.recentMessages.append()
                })
            }
    }
    func fetchCurentUser(){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else{
            self.errorMessage = "ERREUR"
            return
        }
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in if let error = error{
            self.errorMessage = "ERREUR: \(error)"
            print("ERREUR:", error)
            return
            }
          //  self.errorMessage = "123"
            guard let data = snapshot?.data() else {
                self.errorMessage = "ERREUR"
                return
            }
            self.chatUser = .init(data: data)
         //   self.errorMessage = chatUser.profileImageUrl
        }
    }
    func handleSignOut() {
        isUserCurrentlyLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
    }
}

struct MainMessagesView: View {
    @State var shouldShowLogOutOptions = false
    @State var shouldNavigateToChatLogView = false
    @ObservedObject private var vm = MainMessagesViewModel()
    //private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    var body: some View {
        NavigationView{
            
            VStack{
                
               // Text("User : \(vm.chatUser?.uid ?? "")")
                customNavBar
                messagesView
                NavigationLink("", isActive: $shouldNavigateToChatLogView){
                    //ChatLogView(chatUser: self.chatUser)
                    ChatLogView(chatUser: self.chatUser)
                }
            }
            .overlay(
                newMessageButton, alignment: .bottom)
            .navigationBarHidden(true)
        }
    }
    private var customNavBar: some View{
        HStack(spacing: 16){
            
            WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50  , height: 50)
                .cornerRadius(44)
                .clipped()
                .overlay(RoundedRectangle(cornerRadius: 44)
                    .stroke(Color(.label), lineWidth: 1)
                )
                .shadow(radius: 5)
            
         //   Image(systemName: "person.fill")
           //     .font(.system(size: 34, weight: .heavy))
            
            VStack(alignment: .leading, spacing: 4){
                let email = vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? ""
                Text(email)
                    .font(.system(size: 24, weight: .bold))
                HStack{
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14, height: 14)
                    Text("En ligne")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
                
            }
            
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
        }
        .padding()
        .actionSheet(isPresented: $shouldShowLogOutOptions) {
            .init(title: Text("Réglages"), message: Text("Voulez-vous vous déconnecter?"), buttons: [
                .destructive(Text("Se déconnecter"), action: {
                    print("Handle sign out")
                    vm.handleSignOut()
                }),
                //.default(Text("Default button")),
                .cancel()])
        }
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut, onDismiss: nil) {
            ContentView(didCompletLoginProcess: {
                self.vm.isUserCurrentlyLoggedOut = false
                self.vm.fetchCurentUser()
                self.vm.fetchRecentMessages()
            })
        }
    }
    
    private var messagesView: some View{
        ScrollView{
            ForEach(vm.recentMessages){
                recentMessage in
                VStack{
                    NavigationLink {
                        Text("Devrait naviguer à la page de chat.")
                    } label: {
                        HStack(spacing: 16){
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipped()
                                .cornerRadius(64)
                                .overlay(RoundedRectangle(cornerRadius: 64)
                                    .stroke(Color.black, lineWidth: 2))
                                .shadow(radius: 5)
                            VStack(alignment: .leading, spacing: 8){
                                Text(recentMessage.username)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(.label))
                                    .multilineTextAlignment(.leading)
                                Text(recentMessage.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.darkGray))
                                    .multilineTextAlignment(.leading)
                            }
                        
                        Spacer()
                            Text(recentMessage.timeAgo)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.label))
                        }
                    }

                    
                    Divider()
                        .padding(.vertical, 8)
                }.padding(.horizontal)
                
            }.padding(.bottom, 50)
        }
    }
    
    @State var shouldShowNewMessageScreen = false
    private var newMessageButton: some View{
        Button {
            shouldShowNewMessageScreen.toggle()
        } label: {
            HStack{
                Spacer()
                Text("+ Nouveau message")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
                .background(Color.blue)
                .cornerRadius(32)
                .padding(.horizontal)
                .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $shouldShowNewMessageScreen) {
            CreateNewMessageView(didSelectNewUser: {user in
                print(user.email)
                self.shouldNavigateToChatLogView.toggle()
                self.chatUser = user
            })
        }
    }
    @State var chatUser: ChatUser?
}



struct MainMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
            .preferredColorScheme(.dark)
        MainMessagesView()
    }
}
