import Foundation

/// Where a tip can be made. Apple allows an in-app link to another payment method only on the
/// US storefront, so everywhere else tips go through in-app purchase alone.
public enum Donations {
    public static let sponsorsURL = URL(string: "https://github.com/sponsors/arrhen")!

    /// `countryCode` is StoreKit's storefront code (ISO 3166-1 alpha-3, e.g. "USA").
    /// Unknown or missing means no external link.
    public static func showsExternalLink(storefrontCountryCode countryCode: String?) -> Bool {
        countryCode?.uppercased() == "USA"
    }
}
