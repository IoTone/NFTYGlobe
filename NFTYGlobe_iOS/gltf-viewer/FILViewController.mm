/*
 * Copyright (C) 2021 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FILViewController.h"

#import "FILModelView.h"

#include <filament/Scene.h>
#include <filament/Skybox.h>

#include <utils/EntityManager.h>

#include <gltfio/Animator.h>

#include <image/KtxUtility.h>

#include <viewer/AutomationEngine.h>
#include <viewer/RemoteServer.h>
#include <CoreNFC/CoreNFC.h>

using namespace filament;
using namespace utils;

@interface FILViewController ()<NFCNDEFReaderSessionDelegate>
// , NFCReaderSessionDelegate>
- (void)startDisplayLink;
- (void)stopDisplayLink;

- (void)createRenderables;
- (void)createLights;

@property (strong, nonatomic) NFCNDEFReaderSession *session;
@property (strong, nonatomic) NSMutableArray *dataAry;

@end

@implementation FILViewController {
    CADisplayLink* _displayLink;
    CFTimeInterval _startTime;
    viewer::RemoteServer* _server;
    viewer::AutomationEngine* _automation;

    Texture* _skyboxTexture;
    Skybox* _skybox;
    Texture* _iblTexture;
    IndirectLight* _indirectLight;
    Entity _sun;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
/*
#pragma mark - NFCReaderSessionDelegate
- (void)readerSessionDidBecomeActive:(NFCReaderSession *)session
{
    NSLog(@"NFC Session Active");
    if (session.isReady) {
        NSLog(@"NFC Ready");
    } else {
        NSLog(@"NFC Not Ready Yet");
    }
}

- (void)readerSession:(NFCReaderSession *)session
        didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags
{
    NSLog(@"NFC Scan TAG Data");
    
    if (tags.count > 1) {
        // TODO: Handle differently
    }
    
    
}
*/

#pragma mark - NFCNDEFReaderSessionDelegate

- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error
{
    // 读取失败
    NSLog(@"%@",error);
    if (error.code == 201) {
        NSLog(@">>>> NFC Scan Timeout");
        
    }
    
    if (error.code == 200) {
        NSLog(@">>>> NFC Cancel Scan");
    }
}

- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages
{
    
    // Success
    // See a better example here: https://github.com/vinceyuan/VYNFCKit/blob/dbcf214b65e43852a3bbab8a4b2b5ee72661e3c8/Examples/VYNFCKitExampleObjc/VYNFCKitExampleObjc/ViewController.m#L42
    //
    for (NFCNDEFMessage *msg in messages) {
        NSLog(@">>>> NDEF Read Success");
        NSArray *ary = msg.records;
        for (NFCNDEFPayload *rec in ary) {
            
            NFCTypeNameFormat typeName = rec.typeNameFormat;
            NSData *payload = rec.payload;
            NSData *type = rec.type;
            NSData *identifier = rec.identifier;
            NSString *strpayload = [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding];
            NSLog(@">>>> TypeName : %d",typeName);
            NSLog(@">>>> Payload : %@",payload);
            NSLog(@">>>> String Payload : %@ length=%lu",strpayload, strpayload.length);
            NSLog(@">>>> Type : %@",type);
            NSLog(@">>>> Identifier : %@",identifier);
        }
    }
    // TODO: Delay this invalidate by some number of seconds
    self.session.alertMessage = @"NFTY Tag data loading";
    [self.session invalidateSession];
    
    [self.dataAry addObject:messages];
}


#pragma mark UIViewController methods

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"https://google.github.io/filament/remote";

    self.dataAry = [[NSMutableArray alloc] init];
    
    // Arguments:
    // --model <path>
    //     path to glb or gltf file to load from documents directory
    NSString* modelPath = nil;

    NSArray* arguments = [[NSProcessInfo processInfo] arguments];
    for (NSUInteger i = 0; i < arguments.count; i++) {
        NSString* argument = arguments[i];
        NSString* nextArgument = (i + 1) < arguments.count ? arguments[i + 1] : nil;
        if ([argument isEqualToString:@"--model"]) {
            if (!nextArgument) {
                NSLog(@"Warning: --model option requires path argument. None provided.");
            }
            modelPath = nextArgument;
        }
    }

    //
    // Try fetching gltf data from opensea
    //
    // TODO: put this into its own function
    // "https://api.opensea.io/api/v1/asset/0x3b3ee1931dc30c1957379fac9aba94d1c48a5405/69049"
    //
    // Load the JSON first, URL to request from
    NSURLRequest *apirequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://api.opensea.io/api/v1/asset/0x3b3ee1931dc30c1957379fac9aba94d1c48a5405/69049"]];
    [NSURLConnection sendAsynchronousRequest:apirequest queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error) {
            NSLog(@">>> Opensea API Error:%@",error.description);
        }
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            // NSLog(@">>> json :%@",json);
            NSLog(@">>> %@", json);

            // Parse the response
             NSString *animation_url = [json valueForKey:@"animation_url"];
            if (animation_url) {
                [self loadGLTFDataFromURL:animation_url];
            } else {
                NSLog(@">>> Opensea API response missing animation_url, check the contract");
            }
        }
    }];

    
    if (modelPath) {
        [self createRenderablesFromPath:modelPath];
    } else {
        [self createDefaultRenderables];
    }
    [self createLights];

    _server = new viewer::RemoteServer();
    _automation = viewer::AutomationEngine::createDefault();
}

- (IBAction)scanButtonClicked:(id)sender {
    
    [self.session invalidateSession];

    self.session = [[NFCNDEFReaderSession alloc] initWithDelegate:self
                                                            queue:dispatch_get_main_queue()
                                         invalidateAfterFirstRead:NO];
    if (NFCNDEFReaderSession.readingAvailable) {
        self.session.alertMessage = @"Place Tag in scanner area";
        [self.session beginSession];
    } else {
        NSLog(@"This device does not support NFC");
    }
}

- (void)loadGLTFDataFromURL:(NSString*)url {
    //
    // based on https://stackoverflow.com/a/29565794/796514
    // if saving JSON: https://stackoverflow.com/a/17488068/796514
    // Try fetching from opensea:
    NSString *documentDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    // Path and name to save as
    NSString *filePath = [documentDir stringByAppendingPathComponent:@"nft.gltf"];

    // URL to request from
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://storage.opensea.io/files/c494cc38d78d112f497ba4abb84d31ea.gltf"]];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error) {
            NSLog(@">> Download Error:%@",error.description);
        }
        if (data) {
            [data writeToFile:filePath atomically:YES];
            NSLog(@">> File is saved to %@, loading",filePath);
            bool dlexists=[[NSFileManager defaultManager] fileExistsAtPath:filePath];

            if (dlexists) {
                NSLog(@">> File exists");
            } else {
                NSLog(@">> Error File does not exist");
            }
            [self createRenderablesFromAbsPath:filePath];
            [self createLights];
            
            // _server = new viewer::RemoteServer();
            // _automation = viewer::AutomationEngine::createDefault();
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [self startDisplayLink];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self stopDisplayLink];
}

- (void)startDisplayLink {
    [self stopDisplayLink];

    // Call our render method 60 times a second.
    _startTime = CACurrentMediaTime();
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
    _displayLink.preferredFramesPerSecond = 60;
    [_displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
}

- (void)stopDisplayLink {
    [_displayLink invalidate];
    _displayLink = nil;
}

#pragma mark Private

- (void)createRenderablesFromPath:(NSString*)model {
    // Retrieve the full path to the model in the documents directory.
    NSString* documentPath = [NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString* path = [documentPath stringByAppendingPathComponent:model];

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"Error: no file exists at %@", path);
        return;
    }

    NSData* buffer = [NSData dataWithContentsOfFile:path];
    if ([model hasSuffix:@".glb"]) {
        [self.modelView loadModelGlb:buffer];
    } else if ([model hasSuffix:@".gltf"]) {
        NSString* parentDirectory = [path stringByDeletingLastPathComponent];
        [self.modelView loadModelGltf:buffer
                             callback:^NSData*(NSString* uri) {
                                 NSString* p = [parentDirectory stringByAppendingPathComponent:uri];
                                 return [NSData dataWithContentsOfFile:p];
                             }];
    } else {
        NSLog(@"Error: file %@ must have either a .glb or .gltf extension.", path);
        return;
    }

    self.title = model;
    [self.modelView transformToUnitCube];
}

- (void)createRenderablesFromAbsPath:(NSString*)filePath {
    // Retrieve the full path to the model in the documents directory.

    NSString* path = filePath;

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"Error: no file exists at %@", path);
        return;
    }

    NSData* buffer = [NSData dataWithContentsOfFile:path];
    if ([path hasSuffix:@".glb"]) {
        [self.modelView loadModelGlb:buffer];
    } else if ([path hasSuffix:@".gltf"]) {
        NSString* parentDirectory = [path stringByDeletingLastPathComponent];
        [self.modelView loadModelGltf:buffer
                             callback:^NSData*(NSString* uri) {
                                 NSString* p = [parentDirectory stringByAppendingPathComponent:uri];
                                 return [NSData dataWithContentsOfFile:p];
                             }];
    } else {
        NSLog(@"Error: file %@ must have either a .glb or .gltf extension.", path);
        return;
    }

    self.title = path;
    [self.modelView transformToUnitCube];
}

- (void)createDefaultRenderables {
    NSString* path = [[NSBundle mainBundle] pathForResource:@"scene"
                                                     ofType:@"gltf"
                                                inDirectory:@"BusterDrone"];
    assert(path.length > 0);
    NSData* buffer = [NSData dataWithContentsOfFile:path];
    [self.modelView loadModelGltf:buffer
                         callback:^NSData*(NSString* uri) {
                             NSString* p = [[NSBundle mainBundle] pathForResource:uri
                                                                           ofType:@""
                                                                      inDirectory:@"BusterDrone"];
                             return [NSData dataWithContentsOfFile:p];
                         }];
    [self.modelView transformToUnitCube];
}

- (void)createLights {
    // Load Skybox.
    NSString* skyboxPath = [[NSBundle mainBundle] pathForResource:@"default_env_skybox"
                                                           ofType:@"ktx"];
    assert(skyboxPath.length > 0);
    NSData* skyboxBuffer = [NSData dataWithContentsOfFile:skyboxPath];

    image::KtxBundle* skyboxBundle =
            new image::KtxBundle(static_cast<const uint8_t*>(skyboxBuffer.bytes),
                    static_cast<uint32_t>(skyboxBuffer.length));
    _skyboxTexture = image::ktx::createTexture(self.modelView.engine, skyboxBundle, false);
    _skybox = filament::Skybox::Builder().environment(_skyboxTexture).build(*self.modelView.engine);
    self.modelView.scene->setSkybox(_skybox);

    // Load IBL.
    NSString* iblPath = [[NSBundle mainBundle] pathForResource:@"default_env_ibl" ofType:@"ktx"];
    assert(iblPath.length > 0);
    NSData* iblBuffer = [NSData dataWithContentsOfFile:iblPath];

    image::KtxBundle* iblBundle = new image::KtxBundle(
            static_cast<const uint8_t*>(iblBuffer.bytes), static_cast<uint32_t>(iblBuffer.length));
    math::float3 harmonics[9];
    iblBundle->getSphericalHarmonics(harmonics);
    _iblTexture = image::ktx::createTexture(self.modelView.engine, iblBundle, false);
    _indirectLight = IndirectLight::Builder()
                             .reflections(_iblTexture)
                             .irradiance(3, harmonics)
                             .intensity(30000.0f)
                             .build(*self.modelView.engine);
    self.modelView.scene->setIndirectLight(_indirectLight);

    // Always add a direct light source since it is required for shadowing.
    _sun = EntityManager::get().create();
    LightManager::Builder(LightManager::Type::DIRECTIONAL)
            .color(Color::cct(6500.0f))
            .intensity(100000.0f)
            .direction(math::float3(0.0f, -1.0f, 0.0f))
            .castShadows(true)
            .build(*self.modelView.engine, _sun);
    self.modelView.scene->addEntity(_sun);
}

- (void)loadSettings:(viewer::ReceivedMessage const*)message {
    viewer::AutomationEngine::ViewerContent content = {
        .view = self.modelView.view,
        .renderer = self.modelView.renderer,
        .materials = nullptr,
        .materialCount = 0u,
        .lightManager = &self.modelView.engine->getLightManager(),
        .scene = self.modelView.scene,
        .indirectLight = _indirectLight,
        .sunlight = _sun,
    };
    _automation->applySettings(message->buffer, message->bufferByteCount, content);
    ColorGrading* const colorGrading = _automation->getColorGrading(self.modelView.engine);
    self.modelView.view->setColorGrading(colorGrading);
    self.modelView.cameraFocalLength = _automation->getViewerOptions().cameraFocalLength;
}

- (void)loadGlb:(viewer::ReceivedMessage const*)message {
    [self.modelView destroyModel];
    NSData* buffer = [NSData dataWithBytes:message->buffer length:message->bufferByteCount];
    [self.modelView loadModelGlb:buffer];
    [self.modelView transformToUnitCube];
}

- (void)render {
    auto* animator = self.modelView.animator;
    if (animator) {
        if (animator->getAnimationCount() > 0) {
            CFTimeInterval elapsedTime = CACurrentMediaTime() - _startTime;
            animator->applyAnimation(0, static_cast<float>(elapsedTime));
        }
        animator->updateBoneMatrices();
    }

    // Check if a new message has been fully received from the client.
    viewer::ReceivedMessage const* message = _server->acquireReceivedMessage();
    if (message && message->label) {
        NSString* label = [NSString stringWithCString:message->label encoding:NSUTF8StringEncoding];
        if ([label hasSuffix:@".json"]) {
            [self loadSettings:message];
        } else if ([label hasSuffix:@".glb"]) {
            self.title = label;
            [self loadGlb:message];
        }

        _server->releaseReceivedMessage(message);
    }

    [self.modelView render];
}

- (void)dealloc {
    delete _server;
    delete _automation;
    self.modelView.engine->destroy(_indirectLight);
    self.modelView.engine->destroy(_iblTexture);
    self.modelView.engine->destroy(_skybox);
    self.modelView.engine->destroy(_skyboxTexture);
    self.modelView.scene->remove(_sun);
    self.modelView.engine->destroy(_sun);
}

@end
