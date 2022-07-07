//
//  ContentView.swift
//  projetmastercamp
//
//  Created by Vincent Retkowsky on 21/06/2022.
//

import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore


struct ContentView: View {
    
    let didCompletLoginProcess: () -> ()
    
    @State private var chargement = false
    @State private var email = ""
    @State private var password = ""
    @State private var shouldShowImagePicker = false
    
    
    var body: some View {
        NavigationView{
            ScrollView{
                VStack(spacing: 16){
                    Picker(selection: $chargement, label: Text("salut")) {
                        Text("S'enregistrer")
                            .tag(true)
                        Text("Créer un compte")
                            .tag(false)
                    }.pickerStyle(SegmentedPickerStyle())
                        .padding()
                    
                    if !chargement{
                        Button {
                            shouldShowImagePicker.toggle()
                        } label: {
                            
                            VStack{
                                if let image = self.image{
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 128, height: 128)
                                        .cornerRadius(64)
                                } else{
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 64))
                                        .padding()
                                        .foregroundColor(Color(.label))
                                }
                            }
                            
                        }
                    
                        
                    }
                    TextField("Email",text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(.white)
                    SecureField("Mot de passe", text:$password)
                        .padding(12)
                        .background(.white)

                  
                    
                    Button {
                        handleAction()
                    } label: {
                        HStack{
                            Spacer()
                            Text(chargement ? "S'enregistrer" : "Créer un compte")
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }.background(Color.blue)
                    }
                    Text(self.loginStatusMessage)
                        .foregroundColor(.red)
                }
                .padding()
                
            }
            .navigationTitle(chargement ? "S'enregistrer": "Créer un compte ")
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
        }
    }
    
    @State var image: UIImage?
    
    private func handleAction(){
        if chargement{
     //       print("Devrait se connecter à Firebase")
            loginUser()
            }
            else{
                createNewAccount()
            //    print("enregistre toi sur firebase")
            }
    }
    
    private func loginUser() {
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, err in
            if let err = err{
                print("enregistrement échoué:", err)
                self.loginStatusMessage = "enregistrement échoué: \(err)"
                return
            }
            print("enregistrement réussi: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "enregistrement réussi: \(result?.user.uid ?? "")"
            self.didCompletLoginProcess()
        }
    }
    
    
    @State var loginStatusMessage = ""
    
    private func createNewAccount(){
        if self.image == nil {
            self.loginStatusMessage = "You must select an image"
            return
        }
        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, error in
            if let err = error{
                print("création d'utilisateur échoué:", err)
                self.loginStatusMessage = "création d'utilisateur échoué: \(err)"
                return
            }
            print("Utilistaur créé: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Utilistaur créé: \(result?.user.uid ?? "")"
            
            self.PersistImageToStorage()
        }
    }
    
    private func PersistImageToStorage(){
        //let filename = UUID().uuidString
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid
        else{
            return
        }
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else{
            return
        }
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                self.loginStatusMessage = "Failed to push image to storage: \(err)"
                return
            }
            ref.downloadURL { url, err in
                if let err = err{
                    self.loginStatusMessage = "Failed to retrieve downloadURL: \(err)"
                    return
                }
                self.loginStatusMessage = "Stockage d'image réussi \(url?.absoluteString ?? "")"
                //print(url?.absoluteString)
                
                guard let url = url else {
                    return
                }
                self.storeUserInformation(urlProfileUrl: url)
            }
                
        }
    }
    private func storeUserInformation(urlProfileUrl: URL){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            return
        }
        let UserData = ["email": self.email, "uid": uid, "profileImageUrl": urlProfileUrl.absoluteString]
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(UserData) { err in
                if let err = err{
                    self.loginStatusMessage = "\(err)"
                    return
                }
                print("Success")
                self.didCompletLoginProcess()
            }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(didCompletLoginProcess: {
            
        })
            .previewInterfaceOrientation(.portrait)
        
    }
}
