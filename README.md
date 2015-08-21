GeoJSONSerialization
====================

`GeoJSONSerialization` encodes and decodes between [GeoJSON](http://geojson.org) and [GoogleMaps](https://developers.google.com/maps/documentation/ios/reference/index) shapes, following the API conventions of Foundation's `NSJSONSerialization` class.

## Usage

### Decoding

```objective-c
#import <GoogleMaps/GoogleMaps.h>
#import "GeoJSONSerialization.h"

NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"map" withExtension:@"geojson"]];
NSDictionary *geoJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
NSArray *shapes = [GeoJSONSerialization shapesFromGeoJSONFeatureCollection:geoJSON error:nil];

for (GMSOverlay *shape in shapes) {
    shape.map = self.mapView;

    if ([shape isKindOfClass:[GMSMarker class]]) {

    } else if ([shape isKindOfClass:[GMSPolygon class]]) {
        GMSPolygon *poly = (GMSPolygon*)shape;
        poly.fillColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.5f];
        poly.strokeColor = [UIColor redColor];
        poly.strokeWidth = 3;
    } else if ([shape isKindOfClass:[GMSPolyline class]]) {
        GMSPolyline *line = (GMSPolyline*)shape;
        line.strokeColor = [UIColor greenColor];
        line.strokeWidth = 3.0f;
    }
}
```

---

## Contact

Mattt Thompson

- http://github.com/mattt
- http://twitter.com/mattt
- m@mattt.me

## License

GeoJSONSerialization is available under the MIT license. See the LICENSE file for more info.
