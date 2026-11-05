import "./globals.css";

const siteUrl="https://thecrown-rpg.vercel.app";
const previewImage=siteUrl+"/the-crown-pixel-bg.png";

export const metadata={
  metadataBase:new URL(siteUrl),
  title:"The Crown",
  description:"Desafie. Conquiste. Exponha.",
  openGraph:{
    type:"website",
    locale:"pt_BR",
    url:siteUrl,
    siteName:"The Crown",
    title:"The Crown",
    description:"Desafie. Conquiste. Exponha.",
    images:[{
      url:previewImage,
      secureUrl:previewImage,
      width:1200,
      height:630,
      type:"image/png",
      alt:"The Crown — castelo em pixel art neon"
    }]
  },
  twitter:{
    card:"summary_large_image",
    title:"The Crown",
    description:"Desafie. Conquiste. Exponha.",
    images:[previewImage]
  }
};
export default function RootLayout({children}){return <html lang="pt-BR"><body>{children}</body></html>}
