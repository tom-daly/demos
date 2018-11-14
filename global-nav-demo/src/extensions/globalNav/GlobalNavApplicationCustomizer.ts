import { override } from "@microsoft/decorators";
import { Log } from "@microsoft/sp-core-library";
import {
  BaseApplicationCustomizer,
  PlaceholderContent,
  PlaceholderName
} from "@microsoft/sp-application-base";
import * as React from "react";
import * as ReactDom from "react-dom";
import * as strings from "GlobalNavApplicationCustomizerStrings";
import GlobalNav from "./components/GlobalNav/GlobalNav";
const LOG_SOURCE: string = "GlobalNavApplicationCustomizer";

require("./styles.scss");

/**
 * If your command set uses the ClientSideComponentProperties JSON input,
 * it will be deserialized into the BaseExtension.properties object.
 * You can define an interface to describe it.
 */
export interface IGlobalNavApplicationCustomizerProperties {
}

/** A Custom Action which can be run during execution of a Client Side Application */
export default class GlobalNavApplicationCustomizer extends BaseApplicationCustomizer<
  IGlobalNavApplicationCustomizerProperties
> {
  private topPlaceholder: PlaceholderContent | undefined;

  @override
  public onInit(): Promise<void> {
    Log.info(LOG_SOURCE, `Initialized ${strings.Title}`);

    this.context.placeholderProvider.changedEvent.add(
      this,
      this.renderPlaceHolders
    );

    return Promise.resolve();
  }

  private renderPlaceHolders(): void {
    if (!this.topPlaceholder) {
      this.topPlaceholder = this.context.placeholderProvider.tryCreateContent(
        PlaceholderName.Top
      );

      if (!this.topPlaceholder) {
        return;
      }

      if (this.topPlaceholder.domElement) {
        const element: React.ReactElement<{}> = React.createElement(
          GlobalNav,
          {}
        );
        ReactDom.render(element, this.topPlaceholder.domElement);
      }
    }
  }
}
