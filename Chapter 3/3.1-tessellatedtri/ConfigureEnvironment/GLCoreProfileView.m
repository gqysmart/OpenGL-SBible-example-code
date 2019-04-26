//
//  GLCoreProfileView.m
//  ConfigureEnvironment
//
//  Created by 陈杰 on 26/10/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//


#import "GLCoreProfileView.h"
//#import <OpenGL/gl3.h>
#import <OpenGL/OpenGL.h>
#import <GLKit/GLKit.h>

@interface GLCoreProfileView()
@property (atomic, strong) NSTimer *lifeTimer;
@property (atomic, assign) CGFloat lifeDuration;

@property (atomic, assign) GLuint program;
@property (atomic, assign) GLuint vertexArray;
@end

@implementation GLCoreProfileView
#pragma mark - lifecycle methods
- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    if (self = [super initWithCoder:decoder]) {
        [self setOpenGLContext:openGLContext];
        [self.openGLContext makeCurrentContext];
        
        _lifeTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(lifeTimerUpdate) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)dealloc {
    [_lifeTimer invalidate];
    _lifeTimer = nil;
    
    glDeleteVertexArrays(1, &_vertexArray);
    glDeleteProgram(_program);
}

- (void)prepareOpenGL {
    [super prepareOpenGL];
    
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
}

- (void)reshape {
    [super reshape];
    
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    const GLfloat color[] = { 0.3, 0.3,
        0.3f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, color);
    glUseProgram(_program);
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    glDrawArrays(GL_PATCHES, 0, 3);
    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    self.program = glCreateProgram();

    GLuint vertexShader;
    NSString *vertexShaderPath = [[NSBundle mainBundle] pathForResource:@"ShaderV" ofType:@"vsh"];
    if (!vertexShaderPath) {
        NSLog(@"Can not load vertexShader file");
        return NO;
    }
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:vertexShaderPath]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }

    GLuint tControlShader;
    NSString *tControlShaderPath = [[NSBundle mainBundle] pathForResource:@"ShaderTC" ofType:@"vsh"];
    if (!tControlShaderPath) {
        NSLog(@"Can not load tControlShader file");
        return NO;
    }
    if (![self compileShader:&tControlShader type:GL_TESS_CONTROL_SHADER filePath:tControlShaderPath]) {
        NSLog(@"Failed to compile tesselation control shader");
        return NO;
    }
    
    GLuint tEvaluationShader;
    NSString *tEvaluationShaderPath = [[NSBundle mainBundle] pathForResource:@"ShaderTE" ofType:@"vsh"];
    if (!tEvaluationShaderPath) {
        NSLog(@"Can not load tEvaluationShader file");
        return NO;
    }
    if (![self compileShader:&tEvaluationShader type:GL_TESS_EVALUATION_SHADER filePath:tEvaluationShaderPath]) {
        NSLog(@"Failed to compile tesselation evaluation shader");
        return NO;
    }

    GLuint fragShader;
    NSString *fragShaderPath = [[NSBundle mainBundle] pathForResource:@"ShaderF" ofType:@"vsh"];
    if (!fragShaderPath) {
        NSLog(@"Can not load fragShader file");
        return NO;
    }
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fragShaderPath]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, tControlShader);
    glAttachShader(_program, tEvaluationShader);
    glAttachShader(_program, fragShader);
    
    if (vertexShader != 0) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }
    if (tControlShader != 0) {
        glDeleteShader(tControlShader);
        tControlShader = 0;
    }
    if (tEvaluationShader != 0) {
        glDeleteShader(tEvaluationShader);
        tEvaluationShader = 0;
    }
    if (fragShader != 0) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        if (_program != 0) {
            glDeleteProgram(_program);
            _program = 0;
        }
        return NO;
    }
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type filePath:(NSString *)path {
    const GLchar *shaderSource = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil].UTF8String;
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &shaderSource, nil);
    glCompileShader(*shader);
    
    GLint status = 0;
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        GLint logLen = 0;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLen);
        GLchar *infoLog = malloc(sizeof(char) * logLen);
        glGetShaderInfoLog(*shader, logLen, NULL, infoLog);
        NSLog(@"Shader at: %@", path);
        fprintf(stderr, "Info Log: %s\n", infoLog);
        
        glDeleteShader(*shader);
        return NO;
    }
    return YES;
}

- (BOOL)linkProgram:(GLuint)program {
    glLinkProgram(program);
    GLint status = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == 0) {
        GLint logLen = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
        GLchar *infoLog = malloc(sizeof(char) * logLen);
        glGetProgramInfoLog(program, logLen, NULL, infoLog);
        fprintf(stderr, "Prog Info Log: %s\n", infoLog);
        return NO;
    }
    return YES;
}

#pragma mark - listening methods
- (void)lifeTimerUpdate {
    _lifeDuration += _lifeTimer.timeInterval;
    [self drawRect:self.bounds];
}

#pragma mark - accessor methods

@end



