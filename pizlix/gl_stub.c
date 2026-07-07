/* Stub libGL for systems with only GLES/EGL (Wayland-only mesa) */
#include <stddef.h>

typedef unsigned int GLenum;
typedef unsigned char GLboolean;
typedef unsigned int GLuint;
typedef int GLint;
typedef float GLfloat;
typedef double GLdouble;
typedef ptrdiff_t GLsizeiptr;
typedef unsigned int GLbitfield;
typedef int GLsizei;
typedef char GLchar;
typedef unsigned char GLubyte;
typedef void GLvoid;

/* GL 1.0/1.1 functions */
void glBegin(GLenum mode) {}
void glEnd(void) {}
void glVertex2f(GLfloat x, GLfloat y) {}
void glVertex2i(GLint x, GLint y) {}
void glVertex3f(GLfloat x, GLfloat y, GLfloat z) {}
void glVertex3fv(const GLfloat *v) {}
void glColor3f(GLfloat r, GLfloat g, GLfloat b) {}
void glColor3ub(GLubyte r, GLubyte g, GLubyte b) {}
void glColor4f(GLfloat r, GLfloat g, GLfloat b, GLfloat a) {}
void glColor4ub(GLubyte r, GLubyte g, GLubyte b, GLubyte a) {}
void glNormal3f(GLfloat nx, GLfloat ny, GLfloat nz) {}
void glTexCoord2f(GLfloat s, GLfloat t) {}
void glTexCoord2i(GLint s, GLint t) {}
void glEnable(GLenum cap) {}
void glDisable(GLenum cap) {}
GLboolean glIsEnabled(GLenum cap) { return 0; }
void glPushAttrib(GLbitfield mask) {}
void glPopAttrib(void) {}
void glMatrixMode(GLenum mode) {}
void glLoadIdentity(void) {}
void glOrtho(GLdouble l, GLdouble r, GLdouble b, GLdouble t, GLdouble n, GLdouble f) {}
void glFrustum(GLdouble l, GLdouble r, GLdouble b, GLdouble t, GLdouble n, GLdouble f) {}
void glViewport(GLint x, GLint y, GLint w, GLint h) {}
void glPushMatrix(void) {}
void glPopMatrix(void) {}
void glTranslatef(GLfloat x, GLfloat y, GLfloat z) {}
void glRotatef(GLfloat a, GLfloat x, GLfloat y, GLfloat z) {}
void glScalef(GLfloat x, GLfloat y, GLfloat z) {}
void glClear(GLbitfield mask) {}
void glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a) {}
void glClearDepth(GLdouble d) {}
void glFlush(void) {}
void glFinish(void) {}
GLuint glGenLists(GLint range) { return 0; }
void glDeleteLists(GLuint list, GLint range) {}
void glCallList(GLuint list) {}
void glNewList(GLuint list, GLenum mode) {}
void glEndList(void) {}
void glGenTextures(GLint n, GLuint *textures) {}
void glDeleteTextures(GLint n, const GLuint *textures) {}
void glBindTexture(GLenum target, GLuint texture) {}
void glTexImage2D(GLenum target, GLint level, GLint internal, GLint w, GLint h, GLint border, GLenum format, GLenum type, const GLvoid *data) {}
void glTexSubImage2D(GLenum target, GLint level, GLint x, GLint y, GLint w, GLint h, GLenum format, GLenum type, const GLvoid *data) {}
void glTexParameteri(GLenum target, GLenum pname, GLint param) {}
void glGetIntegerv(GLenum pname, GLint *params) {}
void glGetFloatv(GLenum pname, GLfloat *params) {}
void glGetDoublev(GLenum pname, GLdouble *params) {}
void glGetBooleanv(GLenum pname, GLboolean *params) {}
void glReadPixels(GLint x, GLint y, GLint w, GLint h, GLenum format, GLenum type, GLvoid *data) {}
void glDrawPixels(GLint w, GLint h, GLenum format, GLenum type, const GLvoid *data) {}
void glPixelStorei(GLenum pname, GLint param) {}
void glBlendFunc(GLenum sfactor, GLenum dfactor) {}
void glDepthFunc(GLenum func) {}
void glDepthMask(GLboolean flag) {}
void glHint(GLenum target, GLenum mode) {}
void glShadeModel(GLenum mode) {}
void glCullFace(GLenum mode) {}
void glFrontFace(GLenum mode) {}
void glPolygonMode(GLenum face, GLenum mode) {}
void glScissor(GLint x, GLint y, GLint w, GLint h) {}
void glDrawBuffer(GLenum mode) {}
void glReadBuffer(GLenum mode) {}
GLenum glGetError(void) { return 0; }
const GLubyte *glGetString(GLenum name) { return (const GLubyte*)"stub"; }

/* GL 1.2+ */
void glDrawRangeElements(GLenum mode, GLuint start, GLuint end, GLsizei count, GLenum type, const GLvoid *indices) {}
void glTexImage3D(GLenum target, GLint level, GLint internal, GLint w, GLint h, GLint d, GLint border, GLenum format, GLenum type, const GLvoid *data) {}

/* GL 1.3+ */
void glActiveTexture(GLenum texture) {}
void glCompressedTexImage2D(GLenum target, GLint level, GLenum internal, GLint w, GLint h, GLint border, GLsizei size, const GLvoid *data) {}

/* GL 1.5+ */
void glGenBuffers(GLint n, GLuint *buffers) {}
void glDeleteBuffers(GLint n, const GLuint *buffers) {}
void glBindBuffer(GLenum target, GLuint buffer) {}
void glBufferData(GLenum target, GLsizeiptr size, const GLvoid *data, GLenum usage) {}
void glBufferSubData(GLenum target, GLsizeiptr offset, GLsizeiptr size, const GLvoid *data) {}
GLvoid *glMapBuffer(GLenum target, GLenum access) { return NULL; }
GLboolean glUnmapBuffer(GLenum target) { return 1; }

/* GL 2.0+ */
GLuint glCreateShader(GLenum type) { return 0; }
void glDeleteShader(GLuint shader) {}
void glShaderSource(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length) {}
void glCompileShader(GLuint shader) {}
void glGetShaderiv(GLuint shader, GLenum pname, GLint *params) {}
void glGetShaderInfoLog(GLuint shader, GLsizei maxLength, GLsizei *length, GLchar *infoLog) {}
GLuint glCreateProgram(void) { return 0; }
void glDeleteProgram(GLuint program) {}
void glAttachShader(GLuint program, GLuint shader) {}
void glLinkProgram(GLuint program) {}
void glUseProgram(GLuint program) {}
void glGetProgramiv(GLuint program, GLenum pname, GLint *params) {}
void glGetProgramInfoLog(GLuint program, GLsizei maxLength, GLsizei *length, GLchar *infoLog) {}
GLint glGetUniformLocation(GLuint program, const GLchar *name) { return -1; }
GLint glGetAttribLocation(GLuint program, const GLchar *name) { return -1; }
void glBindAttribLocation(GLuint program, GLuint index, const GLchar *name) {}
void glEnableVertexAttribArray(GLuint index) {}
void glDisableVertexAttribArray(GLuint index) {}
void glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid *pointer) {}
void glUniform1i(GLint location, GLint v0) {}
void glUniform1f(GLint location, GLfloat v0) {}
void glUniform2f(GLint location, GLfloat v0, GLfloat v1) {}
void glUniform3f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2) {}
void glUniform4f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3) {}
void glUniformMatrix4fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat *value) {}
void glUniform1fv(GLint location, GLsizei count, const GLfloat *value) {}

/* GL 3.0+ */
void glGenVertexArrays(GLint n, GLuint *arrays) {}
void glDeleteVertexArrays(GLint n, const GLuint *arrays) {}
void glBindVertexArray(GLuint array) {}
void glDrawArrays(GLenum mode, GLint first, GLsizei count) {}
void glDrawElements(GLenum mode, GLsizei count, GLenum type, const GLvoid *indices) {}
const GLubyte *glGetStringi(GLenum name, GLuint index) { return (const GLubyte*)"stub"; }

/* Framebuffer objects */
void glGenFramebuffers(GLint n, GLuint *framebuffers) {}
void glDeleteFramebuffers(GLint n, const GLuint *framebuffers) {}
void glBindFramebuffer(GLenum target, GLuint framebuffer) {}
GLenum glCheckFramebufferStatus(GLenum target) { return 0x8CD5; }
void glGenRenderbuffers(GLint n, GLuint *renderbuffers) {}
void glDeleteRenderbuffers(GLint n, const GLuint *renderbuffers) {}
void glBindRenderbuffer(GLenum target, GLuint renderbuffer) {}
void glRenderbufferStorage(GLenum target, GLenum internalformat, GLint w, GLint h) {}
void glFramebufferRenderbuffer(GLenum target, GLenum attachment, GLenum rendertarget, GLuint renderbuffer) {}
void glFramebufferTexture2D(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level) {}

/* GLX stubs */
int glXQueryExtension(void *dpy, int *errorb, int *event) { return 1; }
int glXQueryVersion(void *dpy, int *maj, int *min) { *maj = 1; *min = 4; return 1; }
void *glXChooseVisual(void *dpy, int screen, int *attribList) { return NULL; }
void *glXCreateContext(void *dpy, void *vis, void *shareList, int direct) { return NULL; }
void glXDestroyContext(void *dpy, void *ctx) {}
int glXMakeCurrent(void *dpy, void *drawable, void *ctx) { return 1; }
void glXSwapBuffers(void *dpy, void *drawable) {}
void *glXCreateGLXPixmap(void *dpy, void *vis, unsigned long pixmap) { return NULL; }
void glXDestroyGLXPixmap(void *dpy, void *pixmap) {}
int glXQueryContext(void *dpy, void *ctx, int attribute, int *value) { return 0; }
unsigned long glXGetCurrentDrawable(void) { return 0; }
void *glXGetCurrentContext(void) { return NULL; }
int glXIsDirect(void *dpy, void *ctx) { return 1; }
int glXGetConfig(void *dpy, void *vis, int attrib, int *value) { return 0; }
void *glXCreateContextAttribsARB(void *dpy, void *config, void *share, int direct, const int *attribs) { return NULL; }
void *glXChooseFBConfig(void *dpy, int screen, const int *attribs, int *nelements) { return NULL; }
void *glXGetVisualFromFBConfig(void *dpy, void *config) { return NULL; }
void *glXCreateNewContext(void *dpy, void *config, int renderType, void *share, int direct) { return NULL; }
void *glXCreatePbuffer(void *dpy, void *config, const int *attribs) { return NULL; }
void glXDestroyPbuffer(void *dpy, void *pbuf) {}
int glXMakeContextCurrent(void *dpy, void *draw, void *read, void *ctx) { return 1; }
void *glXGetProcAddressARB(const char *name) { return NULL; }
void *glXGetProcAddress(const char *name) { return NULL; }
void glXWaitGL(void) {}
void glXWaitX(void) {}
