//
//  ViewController.swift
//  PlantIdentifier
//
//  Created by Anastasia Lenina on 09.05.2023.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate{
    let vc = UIImagePickerController()
    @IBOutlet weak var imageViewDefault: UIImageView!
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        imageViewDefault.isHidden = false
        vc.delegate = self
    }
    
    @IBAction func PhotoButtonPressed(_ sender: UIBarButtonItem) {
        imageViewDefault.isHidden = true
        vc.sourceType = .camera
        vc.allowsEditing = false
        present(vc, animated: true)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage else {
            print("No image found")
            return
        }
        imageView.image = image
        
        let flowerClassifier = FlowerClassifier()
        if let ciImage = CIImage(image: image){
            detect(image: ciImage)
        }
        
    }
    
    func detect(image: CIImage){
        
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else{
            fatalError("Loading CoreML Model Failed")
        }
        let request = VNCoreMLRequest(model: model){
            request, error in
            guard let results = request.results as? [VNClassificationObservation] else{
                fatalError("Model failed to procceds")
            }
            if let firstResult = results.first{

                self.navigationItem.title = firstResult.identifier.capitalized
                self.getFromWIki(searchText:  firstResult.identifier.capitalized)
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        do{
            try handler.perform([request])
        } catch {
            print("\(error)")
        }
        
        
    }
    func getFromWIki(searchText: String){
        let wikipediaURl = "https://en.wikipedia.org/w/api.php?"
        let serachTextSpaceReplaced = searchText.replacingOccurrences(of: " ", with: "%20")
        var parameters : [String:String] = [
            "format" : "json",
            "action" : "query",
            "prop" : "extracts|pageimages",
            "exintro" : "1",
            "explaintext" : "",
            "titles" : searchText,
            "redirects" : "1",
            "indexpageids" : "",
            "pithumbsize" : "500"
        ]
        let urlParamas = "&action=query&format=json&indexpageids&redirects=1&prop=extracts&exintro=&explaintext=&titles="
        
        var finalUrl = wikipediaURl + urlParamas + serachTextSpaceReplaced
        print("URL - \(finalUrl)")

        AF.request(wikipediaURl, method: .get, parameters: parameters).validate().responseJSON { response in
            switch response.result {
            case .success(let value):

                let json = JSON(value)
                let pageId = json["query"]["pageids"][0].stringValue
                let textTitle = json["query"]["pages"]["7435844"]["title"]
                let textBody = json["query"]["pages"][pageId]["extract"]
                let imageURLString = json["query"]["pages"][pageId]["thumbnail"]["source"].stringValue
                self.textLabel.text = textBody.stringValue
    
                if let imageURL = URL(string: imageURLString){
                    self.downloadImage(from: imageURL)
                }
               
            case .failure(let error):
                print(error)
            }
        }
    }
    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
    func downloadImage(from url: URL) {
        print("Download Started")
        getData(from: url) { data, response, error in
            guard let data = data, error == nil else { return }
            print(response?.suggestedFilename ?? url.lastPathComponent)
            print("Download Finished")
            // always update the UI from the main thread
            DispatchQueue.main.async() { [weak self] in
                self?.imageView.image = UIImage(data: data)
            }
        }
    }
    
}


