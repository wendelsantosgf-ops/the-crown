import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "The Crown — Desafie. Conquiste. Exponha.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    <div style={{ width:"100%",height:"100%",display:"flex",position:"relative",alignItems:"center",justifyContent:"center",background:"#11091e",overflow:"hidden" }}>
      <img src="https://thecrown-rpg.vercel.app/the-crown-pixel-bg.png" width="1200" height="630" style={{position:"absolute",width:"100%",height:"100%",objectFit:"cover"}} alt="" />
      <div style={{position:"absolute",inset:0,display:"flex",background:"linear-gradient(180deg,rgba(10,4,26,.3),rgba(10,4,26,.55) 55%,rgba(10,4,26,.86))"}} />
      <div style={{position:"relative",display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",width:"100%",padding:"45px",textAlign:"center"}}>
        <div style={{fontSize:32,color:"#f6c7fa",letterSpacing:12}}>♛</div>
        <div style={{fontSize:105,fontWeight:900,color:"#ffffff",letterSpacing:7,textShadow:"0 5px 20px #2b0c4e"}}>THE CROWN</div>
        <div style={{fontSize:33,fontWeight:700,color:"#ffd1fa",letterSpacing:4,marginTop:18}}>DESAFIE. CONQUISTE. EXPONHA.</div>
      </div>
    </div>,
    size
  );
}
