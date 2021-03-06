#-------------------------------------------------------------------------------
# blend.nim
# Test/demonstrate blend modes.
#-------------------------------------------------------------------------------

import glm
import sokol/[app,appgfx,gfx]
import main

# statements at module scope are executed by sokol/app's init callback
app.setWindowTitle("blend")

# the main.cleanup callback will be invoked when the app window is closed
main.cleanup = proc() = gfx.shutdown()

# the main.event callback will be invoked for each user input event
main.event = proc(e:app.Event) = echo(e.type)

# the main.fail callback will be called in case of any app startup errors
main.fail = proc(s:string) = echo("err: " & s)

const NUM_BLEND_FACTORS = 15

gfx.setup(gfx.Desc(
  context:context(),
  pipelinePoolSize: NUM_BLEND_FACTORS * NUM_BLEND_FACTORS + 1,
))

# quad vertex buffer
var vertices = [
  # position             color0
  -1.0f, -1.0f, 0.0f,    1.0f, 0.0f, 0.0f, 0.5f,
  +1.0f, -1.0f, 0.0f,    0.0f, 1.0f, 0.0f, 0.5f,
  -1.0f, +1.0f, 0.0f,    0.0f, 0.0f, 1.0f, 0.5f,
  +1.0f, +1.0f, 0.0f,    1.0f, 1.0f, 0.0f, 0.5f
]
let vbuf = gfx.makeBuffer(gfx.BufferDesc(
  type:BufferType.VertexBuffer,
  data:vertices,
  label:"cube-vertices",
))
echo "sizeof(vertices):" & $sizeof(vertices)
echo "vbuf:" & $vbuf.id

type FsUniforms = object
  tick:float32

let bgShader = gfx.makeShader(ShaderDesc(
  attrs:[
    ShaderAttrDesc(semName:"POS")
  ],
  vs:ShaderStageDesc(
    source:
      when gfx.gl:
        """
        #version 330
        layout(location=0) in vec2 position;
        void main() {
            gl_Position = vec4(position, 0.5, 1.0);
        }
        """
      elif gfx.metal:
        """
        #include <metal_stdlib>
        using namespace metal;
        struct vs_in {
          float2 position[[attribute(0)]];
        };
        struct vs_out {
          float4 pos [[position]];
        };
        vertex vs_out _main(vs_in in [[stage_in]]) {
          vs_out out;
          out.pos = float4(in.position, 0.5, 1.0);
          return out;
        }
        """
      elif gfx.d3d11:
        """
        struct vs_in {
          float2 pos: POS;
        };
        struct vs_out {
          float4 pos: SV_Position;
        };
        vs_out main(vs_in inp) {
          vs_out outp;
          outp.pos = float4(inp.pos, 0.5, 1.0);
          return outp;
        };
        """
      else:nil,
  ),
  fs:ShaderStageDesc(
    uniformBlocks:[
      ShaderUniformBlockDesc(
        size:sizeof(FsUniforms),
        uniforms:[
          ShaderUniformDesc(name:"tick", type:UniformType.Float),
        ],
      ),
    ],
    source:
      when gfx.gl:
        """
        #version 330
        uniform float tick;
        out vec4 frag_color;
        void main() {
            vec2 xy = fract((gl_FragCoord.xy-vec2(tick)) / 50.0);
            frag_color = vec4(vec3(xy.x*xy.y), 1.0);
        }
        """
      elif gfx.metal:
        """
        #include <metal_stdlib>
        using namespace metal;
        struct params_t {
          float tick;
        };
        fragment float4 _main(float4 frag_coord [[position]], constant params_t& params [[buffer(0)]]) {
          float2 xy = fract((frag_coord.xy-float2(params.tick)) / 50.0);
          return float4(float3(xy.x*xy.y), 1.0);
        }
        """
      elif gfx.d3d11:
        """
        cbuffer params: register(b0) {
          float tick;
        };
        float4 main(float4 frag_coord: SV_Position): SV_Target0 {
          float2 xy = frac((frag_coord.xy-float2(tick,tick)) / 50.0);
          float c = xy.x * xy.y;
          return float4(c, c, c, 1.0);
        };
        """
      else:nil,
  )
))

let bgPipeline = gfx.makePipeline(PipelineDesc(
  layout:LayoutDesc(
    buffers:[
      BufferLayoutDesc(stride:28),
    ],
    attrs:[
      VertexAttrDesc(offset:0, format:VertexFormat.Float2),
    ],
  ),
  shader:bgShader,
  primitiveType:PrimitiveType.TriangleStrip,
  label:"bgPipeline",
))

type VsUniforms = object
  mvp:Mat4f

let quadShader = gfx.makeShader(ShaderDesc(
  attrs:[
    ShaderAttrDesc(semName:"POS"),
    ShaderAttrDesc(semName:"COLOR")
  ],
  vs:ShaderStageDesc(
    uniformBlocks:[
      ShaderUniformBlockDesc(
        size:sizeof(VsUniforms),
        uniforms:[
          ShaderUniformDesc(name:"mvp", type:UniformType.Mat4),
        ],
      ),
    ],
    source:
      when gfx.gl: 
          """
          #version 330
          uniform mat4 mvp;
          layout(location=0) in vec4 position;
          layout(location=1) in vec4 color0;
          out vec4 color;
          void main() {
              gl_Position = mvp * position;
              color = color0;
          }
          """
        elif gfx.metal:
          """
          #include <metal_stdlib>
          using namespace metal;
          struct params_t {
            float4x4 mvp;
          };
          struct vs_in {
            float4 position [[attribute(0)]];
            float4 color [[attribute(1)]];
          };
          struct vs_out {
            float4 pos [[position]];
            float4 color;
          };
          vertex vs_out _main(vs_in in [[stage_in]], constant params_t& params [[buffer(0)]]) {
            vs_out out;
            out.pos = params.mvp * in.position;
            out.color = in.color;
            return out;
          }
          """
        elif gfx.d3d11:
          """
          cbuffer params: register(b0) {
            float4x4 mvp;
          };
          struct vs_in {
            float4 pos: POS;
            float4 color: COLOR;
          };
          struct vs_out {
            float4 color: COLOR;
            float4 pos: SV_Position;
          };
          vs_out main(vs_in inp) {
            vs_out outp;
            outp.pos = mul(mvp, inp.pos);
            outp.color = inp.color;
            return outp;
          }
          """
        else:nil,
  ),
  fs:ShaderStageDesc(
    source:
      when gfx.gl:
        """
        #version 330
        in vec4 color;
        out vec4 frag_color;
        void main() {
            frag_color = color;
        }
        """
      elif gfx.metal:
        """
        #include <metal_stdlib>
        using namespace metal;
        struct fs_in {
          float4 color;
        };
        fragment float4 _main(fs_in in [[stage_in]]) {
          return in.color;
        }
        """
      elif gfx.d3d11:
        """
        float4 main(float4 color: COLOR): SV_Target0 {
          return color;
        }
        """
      else:nil,
  )
))

var pipelines:array[NUM_BLEND_FACTORS, array[NUM_BLEND_FACTORS, Pipeline]]

block:
  var pipelineDesc = gfx.PipelineDesc(
    layout:LayoutDesc(
        attrs:[
            VertexAttrDesc(offset:0,  format:VertexFormat.Float3),
            VertexAttrDesc(offset:12, format:VertexFormat.Float4),
        ],
    ),
    shader:quadShader,
    primitiveType:PrimitiveType.TriangleStrip,
    colors:[
      ColorState(
        blend:BlendState(
          enabled:true,
          srcFactorAlpha:BlendFactor.One,
          dstFactorAlpha:BlendFactor.Zero,
        ),
      ),
    ],
    blendColor:(1f, 0f, 0f, 1f),
  )
  for src in 0..<NUM_BLEND_FACTORS:
    for dst in 0..<NUM_BLEND_FACTORS:
      pipelineDesc.colors[0].blend.srcFactorRgb = (src+1).BlendFactor
      pipelineDesc.colors[0].blend.dstFactorRgb = (dst+1).BlendFactor
      pipelines[src][dst] = makePipeline(pipelineDesc)

var bindings = gfx.Bindings(
  vertexBuffers:[vbuf],
)

# pass action does not clear because the entire screen will be overwritten
var passAction = gfx.PassAction(
  colors:[ColorAttachmentAction(action:Action.DontCare)],
  depth:DepthAttachmentAction(action:Action.DontCare),
  stencil:StencilAttachmentAction(action:Action.DontCare),
)

# a view-projection matrix
var vsUniforms = VsUniforms()
var fsUniforms = FsUniforms()
var r = 0f

main.frame = proc() =
  let proj = perspective(radians(60f), app.widthf()/app.heightf(), 0.01f, 100f)
  let view = lookAt(vec3(0f, 0f, 25f), vec3(0f, 0f, 0f), vec3(0f, 1f, 0f))
  let viewProj = proj * view;

  gfx.beginDefaultPass(passAction, app.width(), app.height())

  # the background quad
  gfx.applyPipeline(bgPipeline)
  gfx.applyBindings(bindings)
  gfx.applyUniforms(ShaderStage.Fragment, 0, fsUniforms)
  gfx.draw(0, 4, 1)

  # the blended quads
  var r0 = r
  for src in 0..<NUM_BLEND_FACTORS:
    for dst in 0..<NUM_BLEND_FACTORS:
      r0 += 0.06f
      let rm = rotate(mat4(1.0f), r0, 0.0f, 1.0f, 0.0f)
      let x = (dst.float32 - NUM_BLEND_FACTORS/2) * 3.0f
      let y = (src.float32 - NUM_BLEND_FACTORS/2) * 2.2f
      let model = translate(mat4(1.0f), x, y, 0.0f) * rm
      vsUniforms.mvp = viewProj * model
      gfx.applyPipeline(pipelines[src][dst])
      gfx.applyBindings(bindings)
      gfx.applyUniforms(ShaderStage.Vertex, 0, vsUniforms)
      gfx.draw(0, 4, 1)
    #
  #

  gfx.endPass()
  gfx.commit()
  r += 0.06f
  fsUniforms.tick += 1f
# main.frame