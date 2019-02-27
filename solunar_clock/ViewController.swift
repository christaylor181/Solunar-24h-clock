//
//  ViewController.swift
//  solunar_clock
//
//  Created by Chris Taylor on 9/3/18.
//  Copyright © 2018 Chris Taylor. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation

var long: Double = 0.0
var lat: Double = 0.0

class DateClass {
    var name: String
    let date = Date()
    let dateFormatter = DateFormatter()
    
    init(name: String) {
        self.name = name
    }
    
    func whatdateisit() -> String {
        dateFormatter.dateFormat = "MM/dd/yyyy"
        return dateFormatter.string(from: date)
    }
    
    func whattimeisit() -> String {
        dateFormatter.dateFormat = "HH:mm"
        return dateFormatter.string(from: date)
    }
    
    func T(unit: String) -> Float {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = unit
        let dateString = dateFormatter.string(from: date)
        return (dateString as NSString).floatValue
    }
}

struct Moon: Codable {
    let curphase: String?
    let moondata: [Moondata]?
    
    struct Moondata: Codable {
        let phen: String
        let time: String
    }
}

struct Sun: Codable {
    let sundata: [Sundata]?
    
    struct Sundata: Codable {
        let phen: String
        let time: String
    }
}

var secsFromGMT: Int { return ((TimeZone.current.secondsFromGMT())/60)/60 }

func decompTime (phenTime: String) -> (hr: Int, min: Int){
    let indexTimestr = phenTime.firstIndex(of: ":")!
    let hr: Int = Int(phenTime[..<indexTimestr])!
    let min: Int = Int(phenTime[indexTimestr...].dropFirst())!
    return(hr, min)
}

class LatLong {
    var latL: String = "00.00"
    var longL: String = "00.00"
    
    func printL(lat: Double, long: Double) -> (latL: String, longL: String) {
        if (lat < 0) {
            latL = String(format: "%.03f", abs(lat)) + "° S"
        } else {
            latL = String(format: "%.03f", lat) + "° N"
        }
        if (long < 0) {
            longL = String(format: "%.03f", abs(long)) + "° W"
        } else {
            longL = String(format: "%.03f", long) + "° E"
        }
        return (latL, longL)
    }
}

class ViewController: UIViewController, CLLocationManagerDelegate {
    var timer = Timer()
    @IBOutlet weak var graphImage: UIImageView!
    @IBOutlet weak var graphImageBkgnd: UIImageView!
    @IBOutlet weak var graphDayRegion: UIImageView!
    @IBOutlet weak var moonRiseLabel: UILabel!
    @IBOutlet weak var moonTransitLabel: UILabel!
    @IBOutlet weak var moonSetLabel: UILabel!
    @IBOutlet weak var sunRiseLabel: UILabel!
    @IBOutlet weak var sunTransitLabel: UILabel!
    @IBOutlet weak var sunSetLabel: UILabel!
    @IBOutlet weak var latLabel: UILabel!
    @IBOutlet weak var longLabel: UILabel!
    @IBOutlet weak var cityLabel: UILabel!
    @IBOutlet weak var countryLabel: UILabel!
    
    var manager: CLLocationManager!
    var location: CLLocation!
    
    func geocode(latitude: Double, longitude: Double, completion: @escaping (CLPlacemark?, Error?) -> ())  {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                completion(nil, error)
                return
            }
            completion(placemark, nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        NotificationCenter.default.addObserver(self, selector: #selector(backgrndObserverMethod), name:NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foregrndObserverMethod), name:NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        self.manager = CLLocationManager()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyKilometer
        self.manager.distanceFilter = 10000
        self.manager.requestWhenInUseAuthorization()
        self.manager.startUpdatingLocation()
        
        self.makeWatchFace()
        self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self,
                                          selector: #selector(self.makeHands),
                                          userInfo: nil, repeats: true)
    
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        lat = locValue.latitude
        long = locValue.longitude
        doURLsessions()
        let latlong = LatLong()
        latLabel.text = latlong.printL(lat: lat, long: long).latL
        longLabel.text = latlong.printL(lat: lat, long: long).longL
        geocode(latitude: lat, longitude: long) { placemark, error in
            guard let placemark = placemark, error == nil else { return }
            DispatchQueue.main.async {
                print("address1:", placemark.thoroughfare ?? "")
                print("address2:", placemark.subThoroughfare ?? "")
                print("city:",     placemark.locality ?? "")
                print("state:",    placemark.administrativeArea ?? "")
                print("zip code:", placemark.postalCode ?? "")
                print("country:",  placemark.country ?? "")
                self.cityLabel.text = (placemark.locality ?? "").uppercased()
                self.countryLabel.text = (placemark.country ?? "").uppercased()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Error with geolocation " + error.localizedDescription)
    }
    
    var moonRise: String = "00:00"
    var moonTransit: String = "00:00"
    var moonSet: String = "00:00"
    var sunRise: String = "00:00"
    var sunTransit: String = "00:00"
    var sunSet: String = "00:00"
    
    @objc func doURLsessions() {
        let now = DateClass(name: "my date for now")
        let sessionMoonTime = URLSession(configuration: URLSessionConfiguration.default)
        if let timeurl =
            URL(string: "https://api.usno.navy.mil/rstt/oneday?date=\(now.whatdateisit())&coords=\(lat),\(long)&tz=\(secsFromGMT)") {
            (sessionMoonTime.dataTask(with: timeurl) { (data, response, error) in
                if let error = error {
                    print("Error: \(error)")
                } else if let data = data {
                    //Uncomment to see what gets sent to the USNO endpoint. Cut'n'paste in a browser to see the JSON returned.
                    //print("timeurl is \(timeurl)")
                    let jsonDecoder = JSONDecoder()
                    let moonresponse = try? jsonDecoder.decode(Moon.self, from: data)
                    if (moonresponse?.moondata != nil) {
                        for item in [moonresponse?.moondata] {
                            for phenitem in item! {
                                switch phenitem.phen {
                                case "R": self.moonRise = phenitem.time
                                case "U": self.moonTransit = phenitem.time
                                case "S": self.moonSet = phenitem.time
                                default: ()
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            self.moonRiseLabel.text = self.moonRise
                            self.moonTransitLabel.text = self.moonTransit
                            self.moonSetLabel.text = self.moonSet
                        }
                    }
                    let sunresponse = try? jsonDecoder.decode(Sun.self, from: data)
                    if (sunresponse?.sundata != nil) {
                        for item in [sunresponse?.sundata] {
                            for phenitem in item! {
                                switch phenitem.phen {
                                case "R": self.sunRise = phenitem.time
                                case "U": self.sunTransit = phenitem.time
                                case "S": self.sunSet = phenitem.time
                                default: ()
                                }
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.sunRiseLabel.text = self.sunRise
                        self.sunTransitLabel.text = self.sunTransit
                        self.sunSetLabel.text = self.sunSet
                    }
                }
                self.makeDayRegion(sriseStr: self.sunRise, ssetStr: self.sunSet, mriseStr: self.moonRise, msetStr: self.moonSet)
            }).resume()
        }
    }
    
    @objc func makeDayRegion(sriseStr: String, ssetStr: String, mriseStr: String, msetStr: String) {
        let dayImagegen:UIImage = UIImage.dayRegionImage(hrRrise: CGFloat(decompTime(phenTime: sriseStr).hr),
                                                         minRrise: CGFloat(decompTime(phenTime: sriseStr).min),
                                                         hrRset: CGFloat(decompTime(phenTime: ssetStr).hr),
                                                         minRset: CGFloat(decompTime(phenTime: ssetStr).min),
                                                         hrMrise: CGFloat(decompTime(phenTime: mriseStr).hr),
                                                         minMrise: CGFloat(decompTime(phenTime: mriseStr).min),
                                                         hrMset: CGFloat(decompTime(phenTime: msetStr).hr),
                                                         minMset: CGFloat(decompTime(phenTime: msetStr).min))
        DispatchQueue.main.async {
            self.graphDayRegion.image = dayImagegen
        }
    }
        
    @objc func makeWatchFace() { //Actually we're making the clock face here
        let faceImagegen:UIImage = UIImage.faceImage()
        graphImageBkgnd.image = faceImagegen
    }
    
    @objc func makeHands() {
        let now = DateClass(name: "my date for now")
        
        let handImagegen:UIImage = UIImage.handImage(hrR: CGFloat(now.T(unit: "HH")),
                                                     minR: CGFloat(now.T(unit: "mm")),
                                                     secR: CGFloat(now.T(unit: "ss")),
                                                     millisecR: CGFloat(now.T(unit: "S")))
        graphImage.image = handImagegen
    }
    
    @objc func backgrndObserverMethod(notification : NSNotification) {
        print("app in background")
        timer.invalidate()
    }
    
    @objc func foregrndObserverMethod(notification : NSNotification) {
        print("app in foreground")
        self.makeWatchFace()
        self.timer = Timer.scheduledTimer(timeInterval: 0.1, target:self, selector: #selector(self.makeHands), userInfo: nil, repeats: true)
    }

}

extension UIImage {
    //Make blue sector giving idea of when the sun is up
    class func dayRegionImage(hrRrise: CGFloat, minRrise: CGFloat, hrRset: CGFloat, minRset: CGFloat,
                              hrMrise: CGFloat, minMrise: CGFloat, hrMset: CGFloat, minMset: CGFloat) -> UIImage!
    {
        let riseAng = (hrRrise * (CGFloat.pi/12)) + (minRrise * (CGFloat.pi/(12*60)))
        let setAng = (hrRset * (CGFloat.pi/12)) + (minRset * (CGFloat.pi/(12*60)))
        let riseMAng = (hrMrise * (CGFloat.pi/12)) + (minMrise * (CGFloat.pi/(12*60)))
        let setMAng = (hrMset * (CGFloat.pi/12)) + (minMset * (CGFloat.pi/(12*60)))
        let size = CGSize(width: 312, height: 312)
        let radius = size.height/2
        UIGraphicsBeginImageContextWithOptions(size, false, CGFloat(2.0))
        let context = UIGraphicsGetCurrentContext()
        var image = UIImage()
        if let context  = context {
            context.setFillColor(UIColor.blue.cgColor)
            context.translateBy(x: radius, y: radius)
            context.rotate(by: (CGFloat.pi/2) * -1)
            
            context.saveGState() //day region
            context.addArc(center: CGPoint(x: 0, y: 0),
                           radius: CGFloat(135),
                           startAngle: riseAng,
                           endAngle: setAng,
                           clockwise: false)
            context.addArc(center: CGPoint(x: 0, y: 0),
                           radius: CGFloat(45),
                           startAngle: setAng,
                           endAngle: riseAng,
                           clockwise: true)
            context.fillPath()
            context.restoreGState()
            
            context.saveGState()  //Make arc representing when the moon is up
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineCap(CGLineCap.round)
            context.setLineWidth(10)
            context.addArc(center: CGPoint(x: 0, y: 0),
                           radius: CGFloat(105),
                           startAngle: riseMAng,
                           endAngle: setMAng,
                           clockwise: false)
            context.strokePath()
            context.restoreGState()
            
            image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        }
        return image
    }
}

extension UIImage {
    class func handImage(hrR: CGFloat, minR: CGFloat, secR: CGFloat, millisecR: CGFloat) -> UIImage! {
        let size = CGSize(width: 312, height: 312)
        let radius = size.height/2
        UIGraphicsBeginImageContextWithOptions(size, false, CGFloat(2.0))
        let context = UIGraphicsGetCurrentContext()
        var image = UIImage()
        if let context  = context {
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineCap(CGLineCap.round)
            context.translateBy(x: radius, y: radius)
            context.rotate(by: CGFloat.pi)
            
            context.saveGState()
            context.setStrokeColor(UIColor.yellow.cgColor)
            context.rotate(by: (((secR + (millisecR*0.1)) * 6) * (CGFloat.pi/180)))
            context.setLineWidth(1.75)                        //second hand
            context.move(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: 0, y: 135))
            context.strokePath()
            context.restoreGState()
            
            context.saveGState()
            context.rotate(by: (minR * (CGFloat.pi/30)) + (secR * (CGFloat.pi/(30*60))))
            context.setLineWidth(2.0)                           //minute hand stub
            context.move(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: 0, y: 12))
            context.strokePath()
            context.restoreGState()
            
            context.saveGState()
            context.rotate(by: (minR * (CGFloat.pi/30)) + (secR * (CGFloat.pi/(30*60))))
            context.setLineWidth(4.5)                          //minute hand extension
            context.move(to: CGPoint(x: 0, y: 13))
            context.addLine(to: CGPoint(x: 0, y: 135))
            context.strokePath()
            context.restoreGState()
            
            context.saveGState()
            context.rotate(by: (hrR * (CGFloat.pi/12)) + (minR * (CGFloat.pi/(12*60))))
            context.setLineWidth(2.0)                           //hour hand stub
            context.move(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: 0, y: 12))
            context.strokePath()
            context.restoreGState()
            
            context.saveGState()
            context.rotate(by: (hrR * (CGFloat.pi/12)) + (minR * (CGFloat.pi/(12*60))))
            context.setLineWidth(5.0)                          //hour hand extension
            context.move(to: CGPoint(x: 0, y: 13))
            context.addLine(to: CGPoint(x: 0, y: 70))
            context.strokePath()
            context.restoreGState()
            
            image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        }
        return image
    }
}

extension UIImage {
    class func faceImage() -> UIImage! {
        //Substitute your font here
        /*let textFontAttributes = [
            NSAttributedStringKey.font: UIFont(name: "Eurostile Next W1G", size: 12) as Any,
            NSAttributedStringKey.foregroundColor: UIColor.white,
            ] as [NSAttributedStringKey : Any]*/
        let textFontAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            ] as [NSAttributedStringKey : Any]
        let size = CGSize(width: 312, height: 312)
        let radius = size.height/2
        UIGraphicsBeginImageContextWithOptions(size, false, CGFloat(2.0))
        let context = UIGraphicsGetCurrentContext()
        var image = UIImage()
        if let context  = context {
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2.0)
            context.translateBy(x: radius, y: radius)
            for num: CGFloat in stride(from: 0, through: 59.0, by: 1) {
                let ang = num * (CGFloat.pi/30)
                if num.truncatingRemainder(dividingBy: 5.0) != 0 {
                    context.saveGState()
                    context.rotate(by: ang)
                    context.translateBy(x: 0, y: radius * 0.98)
                    context.rotate(by: ang * -1)
                    context.move(to: CGPoint(x: 0, y: 0))
                    context.rotate(by: ang)
                    context.addLine(to: CGPoint(x: 0, y: -10))
                    context.strokePath()
                    context.restoreGState()
                } else {
                    let text = ( num == 0 ? " 0" : "\(Int(num))" )
                    /*let textFontAttributes = [
                        NSAttributedStringKey.font: UIFont(name: "Eurostile Next W1G", size: 10) as Any,
                        NSAttributedStringKey.foregroundColor: UIColor.red,
                        ] as [NSAttributedStringKey : Any]*/
                    let textFontAttributes = [
                        NSAttributedStringKey.foregroundColor: UIColor.red,
                        ] as [NSAttributedStringKey : Any]
                    context.saveGState()
                    context.rotate(by: ang)
                    context.translateBy(x: 0, y: (radius * 0.95) * -1)
                    context.rotate(by: ang * -1)
                    let rect = CGRect(origin: CGPoint(x: -8, y: -8), size: size)
                    text.draw(in: rect, withAttributes: textFontAttributes)
                    context.restoreGState()
                }
            }
            for numh: CGFloat in stride(from: 0, to: 24, by: 1) {
                let ang = numh * (CGFloat.pi/12)
                let text = ( numh == 0 ? " 0" : "\(Int(numh))" )
                context.saveGState()
                context.rotate(by: ang)
                context.translateBy(x: 0, y: (radius * 0.80) * -1)
                context.rotate(by: ang * -1)
                let rect = CGRect(origin: CGPoint(x: -9, y: -8), size: size)
                text.draw(in: rect, withAttributes: textFontAttributes)
                context.restoreGState()
            }
            image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        }
        return image
    }
}

