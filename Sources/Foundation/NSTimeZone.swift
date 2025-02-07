// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


@_implementationOnly import CoreFoundation

open class NSTimeZone : NSObject, NSCopying, NSSecureCoding, NSCoding {
    typealias CFType = CFTimeZone
    private var _base = _CFInfo(typeID: CFTimeZoneGetTypeID())
    private var _name: UnsafeMutableRawPointer? = nil
    private var _data: UnsafeMutableRawPointer? = nil
    private var _periods: UnsafeMutableRawPointer? = nil
    private var _periodCnt = Int32(0)
    
    internal final var _cfObject: CFType {
        return unsafeBitCast(self, to: CFType.self)
    }
    
    // Primary creation method is +timeZoneWithName:; the
    // data-taking variants should rarely be used directly
    public convenience init?(name tzName: String) {
        self.init(name: tzName, data: nil)
    }

    public init?(name tzName: String, data aData: Data?) {
        super.init()
        
        /* From https://developer.apple.com/documentation/foundation/nstimezone/1387250-init:
         "Discussion
         As of macOS 10.6, the underlying implementation of this method has been changed to ignore the specified data parameter."
         */
        if !_CFTimeZoneInit(_cfObject, tzName._cfObject, nil) {
            return nil
        }
    }

    public convenience required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        let name = aDecoder.decodeObject(of: NSString.self, forKey: "NS.name")
        let data = aDecoder.decodeObject(of: NSData.self, forKey: "NS.data")

        if name == nil {
            return nil
        }

        self.init(name: String._unconditionallyBridgeFromObjectiveC(name), data: data?._swiftObject)
    }
    
    open override var hash: Int {
        return Int(bitPattern: CFHash(_cfObject))
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSTimeZone else { return false }
        return isEqual(to: other._swiftObject)
    }
    
    open override var description: String {
        return CFCopyDescription(_cfObject)._swiftObject
    }

    deinit {
        _CFDeinit(self)
    }

    // `init(forSecondsFromGMT:)` is not a failable initializer, so we need a designated initializer that isn't failable.
    internal init(_name tzName: String) {
        super.init()
        _CFTimeZoneInit(_cfObject, tzName._cfObject, nil)
    }

    // Time zones created with this never have daylight savings and the
    // offset is constant no matter the date; the name and abbreviation
    // do NOT follow the POSIX convention (of minutes-west).
    public convenience init(forSecondsFromGMT seconds: Int) {
        let sign = seconds < 0 ? "-" : "+"
        let absoluteValue = abs(seconds)
        var minutes = absoluteValue / 60
        if (absoluteValue % 60) >= 30 { minutes += 1 }
        var hours = minutes / 60
        minutes %= 60
        hours = min(hours, 99) // Two digits only; leave CF to enforce actual max offset.
        let mm = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let hh = hours < 10 ? "0\(hours)" : "\(hours)"
        self.init(_name: "GMT" + sign + hh + mm)
    }
    
    public convenience init?(abbreviation: String) {
        let abbr = abbreviation._cfObject
        let possibleName: NSString? = withExtendedLifetime(abbr) {
            return unsafeBitCast(CFDictionaryGetValue(CFTimeZoneCopyAbbreviationDictionary(), unsafeBitCast(abbr, to: UnsafeRawPointer.self)), to: NSString?.self)
        }
        guard let name = possibleName else {
            return nil
        }
        self.init(name: name._swiftObject , data: nil)
    }

    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.name._bridgeToObjectiveC(), forKey:"NS.name")
        // Darwin versions of this method can and will encode mutable data, however it is not required for compatibility
        aCoder.encode(self.data._bridgeToObjectiveC(), forKey:"NS.data")
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    open var name: String {
        guard type(of: self) === NSTimeZone.self else {
            NSRequiresConcreteImplementation()
        }
        return CFTimeZoneGetName(_cfObject)._swiftObject
    }
    
    open var data: Data {
        guard type(of: self) === NSTimeZone.self else {
            NSRequiresConcreteImplementation()
        }
        return CFTimeZoneGetData(_cfObject)._swiftObject
    }
    
    open func secondsFromGMT(for aDate: Date) -> Int {
        guard type(of: self) === NSTimeZone.self else {
            NSRequiresConcreteImplementation()
        }
        return Int(CFTimeZoneGetSecondsFromGMT(_cfObject, aDate.timeIntervalSinceReferenceDate))
    }
    
    open func abbreviation(for aDate: Date) -> String? {
        guard type(of: self) === NSTimeZone.self else {
            NSRequiresConcreteImplementation()
        }
        return CFTimeZoneCopyAbbreviation(_cfObject, aDate.timeIntervalSinceReferenceDate)._swiftObject
    }
    
    open func isDaylightSavingTime(for aDate: Date) -> Bool {
        guard type(of: self) === NSTimeZone.self else {
            NSRequiresConcreteImplementation()
        }
        return CFTimeZoneIsDaylightSavingTime(_cfObject, aDate.timeIntervalSinceReferenceDate)
    }
    
    open func daylightSavingTimeOffset(for aDate: Date) -> TimeInterval {
        guard type(of: self) === NSTimeZone.self else {
            NSRequiresConcreteImplementation()
        }
        return CFTimeZoneGetDaylightSavingTimeOffset(_cfObject, aDate.timeIntervalSinceReferenceDate)
    }
    
    open func nextDaylightSavingTimeTransition(after aDate: Date) -> Date? {
        guard type(of: self) === NSTimeZone.self else {
            NSRequiresConcreteImplementation()
        }
        let ti = CFTimeZoneGetNextDaylightSavingTimeTransition(_cfObject, aDate.timeIntervalSinceReferenceDate)
        guard ti > 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: ti)
    }

    open class var system: TimeZone {
        return CFTimeZoneCopySystem()._swiftObject
    }

    open class func resetSystemTimeZone() {
        CFTimeZoneResetSystem()
    }

    open class var `default`: TimeZone {
        get {
            return CFTimeZoneCopyDefault()._swiftObject
        }
        set {
            CFTimeZoneSetDefault(newValue._cfObject)
        }
    }

    open class var local: TimeZone {
        return TimeZone(adoptingReference: __NSLocalTimeZone.shared, autoupdating: true)
    }

    open class var knownTimeZoneNames: [String] {
        guard let knownNames = CFTimeZoneCopyKnownNames() else { return [] }
        return knownNames._nsObject._bridgeToSwift() as! [String]
    }

    open class var abbreviationDictionary: [String : String] {
        get {
            guard let dictionary = CFTimeZoneCopyAbbreviationDictionary() else { return [:] }
            return dictionary._nsObject._bridgeToSwift() as! [String : String]
        }
        set {
            CFTimeZoneSetAbbreviationDictionary(newValue._cfObject)
        }
    }

    open class var timeZoneDataVersion: String {
        return __CFTimeZoneCopyDataVersionString()._swiftObject
    }

    open var secondsFromGMT: Int {
        let currentDate = Date()
        return secondsFromGMT(for: currentDate)
    }

    /// The abbreviation for the receiver, such as "EDT" (Eastern Daylight Time). (read-only)
    ///
    /// This invokes `abbreviationForDate:` with the current date as the argument.
    open var abbreviation: String? {
        let currentDate = Date()
        return abbreviation(for: currentDate)
    }

    open var isDaylightSavingTime: Bool {
        let currentDate = Date()
        return isDaylightSavingTime(for: currentDate)
    }

    open var daylightSavingTimeOffset: TimeInterval {
        let currentDate = Date()
        return daylightSavingTimeOffset(for: currentDate)
    }

    /*@NSCopying*/ open var nextDaylightSavingTimeTransition: Date?  {
        let currentDate = Date()
        return nextDaylightSavingTimeTransition(after: currentDate)
    }

    open func isEqual(to aTimeZone: TimeZone) -> Bool {
        return CFEqual(self._cfObject, aTimeZone._cfObject)
    }

    open func localizedName(_ style: NameStyle, locale: Locale?) -> String? {
        let cfStyle = CFTimeZoneNameStyle(rawValue: style.rawValue)!
        return CFTimeZoneCopyLocalizedName(self._cfObject, cfStyle, locale?._cfObject ?? CFLocaleCopyCurrent())._swiftObject
    }

}

extension NSTimeZone: _SwiftBridgeable {
    typealias SwiftType = TimeZone
    var _swiftObject: TimeZone { return TimeZone(reference: self) }
}

extension CFTimeZone : _SwiftBridgeable, _NSBridgeable {
    typealias NSType = NSTimeZone
    var _nsObject : NSTimeZone { return unsafeBitCast(self, to: NSTimeZone.self) }
    var _swiftObject: TimeZone { return _nsObject._swiftObject }
}

extension TimeZone : _NSBridgeable {
    typealias NSType = NSTimeZone
    typealias CFType = CFTimeZone
    var _nsObject : NSTimeZone { return _bridgeToObjectiveC() }
    var _cfObject : CFTimeZone { return _nsObject._cfObject }
}

extension NSTimeZone {

    public enum NameStyle : Int {
        case standard    // Central Standard Time
        case shortStandard    // CST
        case daylightSaving    // Central Daylight Time
        case shortDaylightSaving    // CDT
        case generic    // Central Time
        case shortGeneric    // CT
    }

}

#if !os(WASI)
extension NSNotification.Name {
    public static let NSSystemTimeZoneDidChange = NSNotification.Name(rawValue: kCFTimeZoneSystemTimeZoneDidChangeNotification._swiftObject)
}
#endif

internal class __NSLocalTimeZone: NSTimeZone {
    static var shared = __NSLocalTimeZone()

    private init() {
        super.init(_name: "GMT+0000")
    }

    public convenience required init?(coder aDecoder: NSCoder) {
        // We do not encode details of the local time zone, merely the placeholder object.
        self.init()
    }

    override func encode(with aCoder: NSCoder) {
        // We do not encode details of the local time zone, merely the placeholder object.
    }
    
    private var system: NSTimeZone {
        return NSTimeZone.system._nsObject
    }
    
    override var name: String { return system.name }
    override var data: Data { return system.data }
    override func secondsFromGMT(for aDate: Date) -> Int {
        return system.secondsFromGMT(for: aDate)
    }
    override func abbreviation(for aDate: Date) -> String? {
        return system.abbreviation(for: aDate)
    }
    override func isDaylightSavingTime(for aDate: Date) -> Bool {
        return system.isDaylightSavingTime(for: aDate)
    }
    override func daylightSavingTimeOffset(for aDate: Date) -> TimeInterval {
        return system.daylightSavingTimeOffset(for: aDate)
    
    }
    override func nextDaylightSavingTimeTransition(after aDate: Date) -> Date? {
        return system.nextDaylightSavingTimeTransition(after: aDate)
    }
    override func localizedName(_ style: NSTimeZone.NameStyle, locale: Locale?) -> String? {
        return system.localizedName(style, locale: locale)
    }
    override var description: String {
        return "Local Time Zone (\(system.description))"
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
}
