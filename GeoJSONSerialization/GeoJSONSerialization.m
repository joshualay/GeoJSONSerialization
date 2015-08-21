// GeoJSONSerialization.m
// 
// Copyright (c) 2014 Mattt Thompson
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

#import "GeoJSONSerialization.h"

#pragma mark - Geometry Primitives

NSString * const GeoJSONSerializationErrorDomain = @"com.geojson.serialization.error";

static inline double CLLocationCoordinateNormalizedLatitude(double latitude) {
    return fmod((latitude + 90.0f), 180.0f) - 90.0f;
}

static inline double CLLocationCoordinateNormalizedLongitude(double latitude) {
    return fmod((latitude + 180.0f), 360.0f) - 180.0f;
}

static inline CLLocationCoordinate2D CLLocationCoordinateFromCoordinates(NSArray *coordinates) {
    NSCParameterAssert(coordinates && [coordinates count] >= 2);

    NSNumber *longitude = coordinates[0];
    NSNumber *latitude = coordinates[1];

    return CLLocationCoordinate2DMake(CLLocationCoordinateNormalizedLatitude([latitude doubleValue]), CLLocationCoordinateNormalizedLongitude([longitude doubleValue]));
}

static inline CLLocationCoordinate2D * CLCreateLocationCoordinatesFromCoordinatePairs(NSArray *coordinatePairs) {
    NSUInteger count = [coordinatePairs count];
    CLLocationCoordinate2D *locationCoordinates = malloc(sizeof(CLLocationCoordinate2D) * count);
    for (NSUInteger idx = 0; idx < count; idx++) {
        CLLocationCoordinate2D coordinate = CLLocationCoordinateFromCoordinates(coordinatePairs[idx]);
        locationCoordinates[idx] = coordinate;
    }

    return locationCoordinates;
}

static GMSMarker * GMSMarkerFromGeoJSONPointFeature(NSDictionary *feature) {
    NSDictionary *geometry = feature[@"geometry"];

    NSCParameterAssert([geometry[@"type"] isEqualToString:@"Point"]);

    GMSMarker *pointAnnotation = [[GMSMarker alloc] init];
    pointAnnotation.position = CLLocationCoordinateFromCoordinates(geometry[@"coordinates"]);

    NSDictionary *properties = [NSDictionary dictionaryWithDictionary:feature[@"properties"]];
    pointAnnotation.title = properties[@"title"];

    return pointAnnotation;
}

static GMSPolyline * GMSPolylineFromGeoJSONLineStringFeature(NSDictionary *feature) {
    NSDictionary *geometry = feature[@"geometry"];

    NSCParameterAssert([geometry[@"type"] isEqualToString:@"LineString"]);

    NSArray *coordinatePairs = geometry[@"coordinates"];
    CLLocationCoordinate2D *polylineCoordinates = CLCreateLocationCoordinatesFromCoordinatePairs(coordinatePairs);

    GMSMutablePath *path = [GMSMutablePath path];
    for( NSInteger i = 0; i < [coordinatePairs count]; i++)
    {
        CLLocationCoordinate2D coord = polylineCoordinates[i];
        [path addCoordinate:coord];
    }

    GMSPolyline *polyLine = [GMSPolyline polylineWithPath:path];

    NSDictionary *properties = [NSDictionary dictionaryWithDictionary:feature[@"properties"]];
    polyLine.title = properties[@"title"];

    return polyLine;
}

static GMSPolygon * GMSPolygonFromGeoJSONPolygonFeature(NSDictionary *feature) {
    NSDictionary *geometry = feature[@"geometry"];

    NSCParameterAssert([geometry[@"type"] isEqualToString:@"Polygon"]);

    NSArray *coordinateSets = geometry[@"coordinates"];

    NSMutableArray *mutablePolygons = [NSMutableArray arrayWithCapacity:[coordinateSets count]];
    for (NSArray *coordinatePairs in coordinateSets) {
        CLLocationCoordinate2D *polygonCoordinates = CLCreateLocationCoordinatesFromCoordinatePairs(coordinatePairs);
        GMSMutablePath *path = [GMSMutablePath path];
        for( NSInteger i = 0; i < [coordinatePairs count]; i++)
        {
            CLLocationCoordinate2D coord = polygonCoordinates[i];
            [path addCoordinate:coord];
        }

        GMSPolygon *polygon = [GMSPolygon polygonWithPath:path];
        [mutablePolygons addObject:polygon];
        free(polygonCoordinates);
    }

    GMSPolygon *polygon = nil;
    switch ([mutablePolygons count]) {
        case 0:
            return nil;
        case 1:
            polygon = [mutablePolygons firstObject];
            break;
        default: {
// TODO: Google Maps current does not support interior polygons. Once the API does add it in here.
// https://code.google.com/p/gmaps-api-issues/issues/detail?id=5464&q=apitype=IosSDK&colspec=ID%20Type%20Status%20Introduced%20Fixed%20Summary%20Stars%20ApiType%20Internal
        }
            break;
    }

    NSDictionary *properties = [NSDictionary dictionaryWithDictionary:feature[@"properties"]];
    polygon.title = properties[@"title"];

    return polygon;
}

#pragma mark - Multipart Geometries

static NSArray * MKPointAnnotationsFromGeoJSONMultiPointFeature(NSDictionary *feature) {
    NSDictionary *geometry = feature[@"geometry"];

    NSCParameterAssert([geometry[@"type"] isEqualToString:@"MultiPoint"]);

    NSArray *coordinatePairs = geometry[@"coordinates"];
    NSDictionary *properties = [NSDictionary dictionaryWithDictionary:feature[@"properties"]];

    NSMutableArray *mutablePointAnnotations = [NSMutableArray arrayWithCapacity:[coordinatePairs count]];
    for (NSArray *coordinates in coordinatePairs) {
        NSDictionary *subFeature = @{
                                     @"type": @"Feature",
                                     @"geometry": @{
                                             @"type": @"Point",
                                             @"coordinates": coordinates
                                             },
                                     @"properties": properties
                                     };

        [mutablePointAnnotations addObject:GMSMarkerFromGeoJSONPointFeature(subFeature)];
    }

    return [NSArray arrayWithArray:mutablePointAnnotations];
}

static NSArray * MKPolylinesFromGeoJSONMultiLineStringFeature(NSDictionary *feature) {
    NSDictionary *geometry = feature[@"geometry"];

    NSCParameterAssert([geometry[@"type"] isEqualToString:@"MultiLineString"]);

    NSArray *coordinateSets = geometry[@"coordinates"];
    NSDictionary *properties = [NSDictionary dictionaryWithDictionary:feature[@"properties"]];

    NSMutableArray *mutablePolylines = [NSMutableArray arrayWithCapacity:[coordinateSets count]];
    for (NSArray *coordinatePairs in coordinateSets) {
        NSDictionary *subFeature = @{
                                     @"type": @"Feature",
                                     @"geometry": @{
                                             @"type": @"LineString",
                                             @"coordinates": coordinatePairs
                                             },
                                     @"properties": properties
                                     };

        [mutablePolylines addObject:GMSPolylineFromGeoJSONLineStringFeature(subFeature)];
    }

    return [NSArray arrayWithArray:mutablePolylines];
}

static NSArray * MKPolygonsFromGeoJSONMultiPolygonFeature(NSDictionary *feature) {
    NSDictionary *geometry = feature[@"geometry"];

    NSCParameterAssert([geometry[@"type"] isEqualToString:@"MultiPolygon"]);

    NSArray *coordinateGroups = geometry[@"coordinates"];
    NSDictionary *properties = [NSDictionary dictionaryWithDictionary:feature[@"properties"]];

    NSMutableArray *mutablePolylines = [NSMutableArray arrayWithCapacity:[coordinateGroups count]];
    for (NSArray *coordinateSets in coordinateGroups) {
        NSDictionary *subFeature = @{
                                     @"type": @"Feature",
                                     @"geometry": @{
                                             @"type": @"Polygon",
                                             @"coordinates": coordinateSets
                                             },
                                     @"properties": properties
                                     };

        [mutablePolylines addObject:GMSPolygonFromGeoJSONPolygonFeature(subFeature)];
    }

    return [NSArray arrayWithArray:mutablePolylines];
}

#pragma mark -

static id GMSPolygonFromGeoJSONFeature(NSDictionary *feature) {
    NSCParameterAssert([feature[@"type"] isEqualToString:@"Feature"]);

    NSDictionary *geometry = feature[@"geometry"];
    NSString *type = geometry[@"type"];
    if ([type isEqualToString:@"Point"]) {
        return GMSMarkerFromGeoJSONPointFeature(feature);
    } else if ([type isEqualToString:@"LineString"]) {
        return GMSPolylineFromGeoJSONLineStringFeature(feature);
    } else if ([type isEqualToString:@"Polygon"]) {
        return GMSPolygonFromGeoJSONPolygonFeature(feature);
    } else if ([type isEqualToString:@"MultiPoint"]) {
        return MKPointAnnotationsFromGeoJSONMultiPointFeature(feature);
    } else if ([type isEqualToString:@"MultiLineString"]) {
        return MKPolylinesFromGeoJSONMultiLineStringFeature(feature);
    } else if ([type isEqualToString:@"MultiPolygon"]) {
        return MKPolygonsFromGeoJSONMultiPolygonFeature(feature);
    }

    return nil;
}

static NSArray * GMSOverlaysFromGeoJSONFeatureCollection(NSDictionary *featureCollection) {
    NSCParameterAssert([featureCollection[@"type"] isEqualToString:@"FeatureCollection"]);

    NSMutableArray *mutableShapes = [NSMutableArray array];
    for (NSDictionary *feature in featureCollection[@"features"]) {
        id shape = GMSPolygonFromGeoJSONFeature(feature);
        if (shape) {
            if ([shape isKindOfClass:[NSArray class]]) {
                [mutableShapes addObjectsFromArray:shape];
            } else {
                [mutableShapes addObject:shape];
            }
        }
    }
    
    return [NSArray arrayWithArray:mutableShapes];
}

#pragma mark -

static inline NSDictionary * GeoJSONPropertiesForShape(GMSOverlay *shape) {
    NSMutableDictionary *mutableProperties = [NSMutableDictionary dictionary];
    if (shape.title) {
        mutableProperties[@"title"] = shape.title;
    }

    return [NSDictionary dictionaryWithDictionary:mutableProperties];
}

static NSDictionary * GeoJSONPointFeatureGeometryFromPointAnnotation(GMSMarker *pointAnnotation) {
    NSArray *coordinates = @[
                             @(pointAnnotation.position.longitude),
                             @(pointAnnotation.position.latitude)
                             ];

    return @{
             @"type": @"Point",
             @"coordinates": coordinates
             };
}

static NSDictionary * GeoJSONLineStringFeatureGeometryFromPolyline(GMSPolyline *polyline) {
    NSMutableArray *mutableCoordinatePairs = [NSMutableArray arrayWithCapacity:[polyline.path count]];
    for (NSUInteger idx = 0; idx < [polyline.path count]; idx++) {
        CLLocationCoordinate2D coordinate = [polyline.path coordinateAtIndex:idx];
        [mutableCoordinatePairs addObject:@[@(coordinate.longitude), @(coordinate.latitude)]];
    }

    return @{
             @"type": @"LineString",
             @"coordinates": mutableCoordinatePairs
             };
}

static NSDictionary * GeoJSONPolygonFeatureGeometryFromPolygon(GMSPolygon *polygon) {
    // TODO: Google Maps current does not support interior polygons. Once the API does add it in here.

    NSMutableArray *mutableCoordinateSets = [NSMutableArray arrayWithCapacity:1];
    NSMutableArray *mutablePolygons = [NSMutableArray arrayWithObject:polygon];
    for (GMSPolygon *polygon in mutablePolygons) {
        NSMutableArray *mutableCoordinatePairs = [NSMutableArray arrayWithCapacity:[polygon.path count]];
        for (NSUInteger idx = 0; idx < [polygon.path count]; idx++) {
            CLLocationCoordinate2D coordinate = [polygon.path coordinateAtIndex:idx];
            [mutableCoordinatePairs addObject:@[@(coordinate.longitude), @(coordinate.latitude)]];
        }

        [mutableCoordinateSets addObject:mutableCoordinatePairs];
    }

    return @{
             @"type": @"Polygon",
             @"coordinates": mutableCoordinateSets
             };
}

static NSDictionary * GeoJSONFeatureFromShape(GMSOverlay *shape, NSDictionary *properties) {
    NSDictionary *geometry = nil;
    if ([shape isKindOfClass:[GMSPolygon class]]) {
        geometry = GeoJSONPolygonFeatureGeometryFromPolygon((GMSPolygon *)shape);
    } else if ([shape isKindOfClass:[GMSPolyline class]]) {
        geometry = GeoJSONLineStringFeatureGeometryFromPolyline((GMSPolyline *)shape);
    } else if ([shape isKindOfClass:[GMSMarker class]]) {
        geometry = GeoJSONPointFeatureGeometryFromPointAnnotation((GMSMarker *)shape);
    } else {
        return nil;
    }

    NSMutableDictionary *mutableProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
    [mutableProperties addEntriesFromDictionary:GeoJSONPropertiesForShape(shape)];

    return @{
             @"type": @"Feature",
             @"geometry": geometry,
             @"properties": mutableProperties
             };
}

static NSDictionary * GeoJSONFeatureCollectionFromShapes(NSArray *shapes, NSArray *arrayOfProperties) {
    NSMutableArray *mutableFeatures = [NSMutableArray arrayWithCapacity:[shapes count]];

    [shapes enumerateObjectsUsingBlock:^(GMSOverlay *shape, NSUInteger idx, __unused BOOL *stop) {
        NSDictionary *properties = arrayOfProperties[idx];
        NSDictionary *feature = GeoJSONFeatureFromShape(shape, properties);
        if (feature) {
            [mutableFeatures addObject:feature];
        }
    }];

    return @{
             @"type": @"FeatureCollection",
             @"features": mutableFeatures
             };
}

#pragma mark -


@implementation GeoJSONSerialization

+ (GMSOverlay *)shapeFromGeoJSONFeature:(NSDictionary *)feature
                               error:(NSError * __autoreleasing *)error
{
    @try {
        return GMSPolygonFromGeoJSONFeature(feature);
    }
    @catch (NSException *exception) {
        if (error) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: exception.name,
                                       NSLocalizedFailureReasonErrorKey: exception.reason
                                       };

            *error = [NSError errorWithDomain:GeoJSONSerializationErrorDomain code:-1 userInfo:userInfo];
        }

        return nil;
    }
}

+ (NSArray *)shapesFromGeoJSONFeatureCollection:(NSDictionary *)featureCollection
                                          error:(NSError * __autoreleasing *)error
{
    @try {
        return GMSOverlaysFromGeoJSONFeatureCollection(featureCollection);
    }
    @catch (NSException *exception) {
        if (error) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: exception.name,
                                       NSLocalizedFailureReasonErrorKey: exception.reason
                                       };

            *error = [NSError errorWithDomain:GeoJSONSerializationErrorDomain code:-1 userInfo:userInfo];
        }

        return nil;
    }
}

#pragma mark -

+ (NSDictionary *)GeoJSONFeatureFromShape:(GMSOverlay *)shape
                               properties:(NSDictionary *)properties
                                    error:(NSError * __autoreleasing *)error
{
    return GeoJSONFeatureFromShape(shape, properties);
}

+ (NSDictionary *)GeoJSONFeatureCollectionFromShapes:(NSArray *)shapes
                                          properties:(NSArray *)arrayOfProperties
                                               error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(!arrayOfProperties || [shapes count] == [arrayOfProperties count]);

    return GeoJSONFeatureCollectionFromShapes(shapes, arrayOfProperties);
}

@end
