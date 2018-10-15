import * as React from "react";
import styles from "./HelloWorld.module.scss";
import { IHelloWorldProps } from "./IHelloWorldProps";
import * as jQuery from "jquery";
import "jqueryui";
import { SPComponentLoader } from "@microsoft/sp-loader";

export default class HelloWorld extends React.Component<IHelloWorldProps, {}> {
  public constructor() {
    super();
    SPComponentLoader.loadCss(
      "//code.jquery.com/ui/1.11.4/themes/smoothness/jquery-ui.css"
    );
  }

  public componentDidMount(): void {
    const accordionOptions: JQueryUI.AccordionOptions = {
      animate: true,
      collapsible: false,
      icons: {
        header: 'ui-icon-circle-arrow-e',
        activeHeader: 'ui-icon-circle-arrow-s'
      }
     };

     jQuery('.accordion').accordion(accordionOptions);
  }

  public render(): React.ReactElement<IHelloWorldProps> {
    return (
      <div className="accordion">
        <h3>Section 1</h3>
        <div>
          <p>
          Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam mattis justo ac nulla ultrices, at aliquet orci hendrerit. Fusce lacus lorem, elementum in elit vel, efficitur vehicula sem. Nullam tincidunt eros dolor. Suspendisse id tincidunt felis, sed rutrum odio. Donec vel tempus dolor, vitae tincidunt massa. Sed nec ultricies urna, vel suscipit dui. Fusce convallis semper interdum. Praesent tristique turpis et metus sollicitudin pretium. Suspendisse potenti. Nam mattis at eros in euismod. Integer est ipsum, dignissim at maximus ac, suscipit eget diam.
          </p>
        </div>
        <h3>Section 2</h3>
        <div>
          <p>
            Sed non urna. Donec et ante. Phasellus eu ligula. Vestibulum sit
            amet purus. Vivamus hendrerit, dolor at aliquet laoreet, mauris
            turpis porttitor velit, faucibus interdum tellus libero ac justo.
            Vivamus non quam. In suscipit faucibus urna.
          </p>
        </div>
        <h3>Section 3</h3>
        <div>
          <p>
          Aliquam erat volutpat. Praesent pretium rhoncus velit sit amet hendrerit. Aenean lobortis nibh nisl, ac aliquet mauris semper eget. Maecenas viverra cursus velit, ac pulvinar nisi sollicitudin id. Nullam sed pellentesque nibh. Cras commodo elit vitae neque tincidunt condimentum. Nam commodo risus eu diam venenatis lacinia. Pellentesque sed enim id risus consectetur semper imperdiet sit amet quam. Quisque lobortis sem et sollicitudin malesuada. Vestibulum ac eleifend lacus. Fusce mollis vestibulum enim, non malesuada tortor ultricies eu. Vivamus non dui sed diam aliquet ornare. In hac habitasse platea dictumst. Suspendisse eu bibendum ante, at dapibus velit. Proin non interdum diam, id luctus massa. Vivamus eget magna convallis mauris feugiat faucibus eget eget turpis.
          </p>
          <ul>
            <li>List item one</li>
            <li>List item two</li>
            <li>List item three</li>
          </ul>
        </div>
        <h3>Section 4</h3>
        <div>
          <p>
          In hac habitasse platea dictumst. Nam sodales velit quis nisi vulputate, non blandit sem tincidunt. Donec fermentum tortor et rhoncus aliquet. Pellentesque vitae faucibus turpis. Nullam ut arcu consequat, dignissim arcu at, volutpat magna. Etiam ac pretium nibh, et scelerisque nisl. Proin non libero varius, vulputate massa nec, blandit felis. Phasellus et efficitur purus. Integer mattis luctus nunc vitae mollis. In lacinia lectus eu ex venenatis, vel dictum ex sodales. Integer eget felis accumsan nibh posuere auctor viverra vel dui. Donec sit amet volutpat lectus. Phasellus consequat viverra justo, non bibendum orci malesuada in. Nullam aliquam eros non magna lacinia, vitae fermentum dolor sagittis. Nulla facilisi.
          </p>
          <p>
          Mauris eu fringilla libero. Nam lacinia tincidunt lectus, vel consequat mi sagittis ac. Fusce elit velit, tempor sit amet metus id, vulputate placerat ante. Duis cursus purus sed nisl tincidunt, eu fermentum sem ultrices. Mauris nec placerat urna. Phasellus metus libero, malesuada id placerat quis, laoreet eu metus. Nullam dignissim semper mi non tincidunt. Etiam interdum eu magna a iaculis.
          </p>
        </div>
      </div>
    );
  }
}
