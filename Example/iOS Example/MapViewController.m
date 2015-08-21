// MapViewController.m
// 
// Copyright (c) 2014年 Mattt Thompson
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MapViewController.h"

#import <GoogleMaps/GoogleMaps.h>

#import "GeoJSONSerialization.h"

@interface MapViewController () <GMSMapViewDelegate>
@property (readwrite, nonatomic, strong) GMSMapView *mapView;
@end

@implementation MapViewController

#pragma mark - UIViewController

- (void)loadView {
    [super loadView];

    [GMSServices provideAPIKey:@"AIzaSyBFED3d-TFIJfnmlJF2JauRoxUMGBAHSxg"];

    self.mapView = [[GMSMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;

    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedString(@"GeoJSON Serialization", nil);

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
}

@end
