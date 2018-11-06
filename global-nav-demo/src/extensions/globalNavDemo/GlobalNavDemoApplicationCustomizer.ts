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

const LOG_SOURCE: string = "GlobalNavDemoApplicationCustomizer";

export interface IGlobalNavDemoApplicationCustomizerProperties {}

/** A Custom Action which can be run during execution of a Client Side Application */
export default class GlobalNavDemoApplicationCustomizer extends BaseApplicationCustomizer<
  IGlobalNavDemoApplicationCustomizerProperties
> {
  private topPlaceholder: PlaceholderContent | undefined;

  @override
  public onInit(): Promise<void> {
    Log.info(LOG_SOURCE, `Initialized ${strings.Title}`);

    this.context.placeholderProvider.changedEvent.add(
      this,
      this.renderPlaceHolders
    );
    this.renderPlaceHolders();

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
