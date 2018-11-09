import { override } from "@microsoft/decorators";
import { Log } from "@microsoft/sp-core-library";
import {
  BaseApplicationCustomizer,
  PlaceholderContent,
  PlaceholderName
} from "@microsoft/sp-application-base";
import * as strings from "GlobalNavDemoApplicationCustomizerStrings";
import * as React from "react";
import * as ReactDom from "react-dom";
import GlobalNav from "./GlobaNavPlaceholder";
import pnp from "sp-pnp-js/lib/pnp";

const LOG_SOURCE: string = "GlobalNavDemoApplicationCustomizer";

require("./globalNavDemo.scss");

export interface IGlobalNavDemoApplicationCustomizerProperties {}

/** A Custom Action which can be run during execution of a Client Side Application */
export default class GlobalNavDemoApplicationCustomizer extends BaseApplicationCustomizer<
  IGlobalNavDemoApplicationCustomizerProperties
> {
  private topPlaceholder: PlaceholderContent | undefined;

  @override
  public onInit(): Promise<void> {
    return super.onInit().then(() => {
      pnp.setup({
        spfxContext: this.context,
        defaultCachingStore: "session",
        globalCacheDisable: false
      });

      this.context.placeholderProvider.changedEvent.add(
        this,
        this.renderPlaceHolders
      );
      this.renderPlaceHolders();
    });
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
