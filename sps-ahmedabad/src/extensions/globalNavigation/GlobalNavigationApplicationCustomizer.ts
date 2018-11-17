import { override } from '@microsoft/decorators';
import { Log } from '@microsoft/sp-core-library';
import {
  BaseApplicationCustomizer, 
  PlaceholderContent,
  PlaceholderName
} from '@microsoft/sp-application-base';
import { Dialog } from '@microsoft/sp-dialog';
import * as React from "react";
import * as ReactDom from "react-dom";
import GlobalNav from "./components/GlobalNav/GlobalNav";

import * as strings from 'GlobalNavigationApplicationCustomizerStrings';

const LOG_SOURCE: string = 'GlobalNavigationApplicationCustomizer';

require("./styles.scss");

/**
 * If your command set uses the ClientSideComponentProperties JSON input,
 * it will be deserialized into the BaseExtension.properties object.
 * You can define an interface to describe it.
 */
export interface IGlobalNavigationApplicationCustomizerProperties {
  // This is an example; replace with your own property
  testMessage: string;
}

/** A Custom Action which can be run during execution of a Client Side Application */
export default class GlobalNavigationApplicationCustomizer
  extends BaseApplicationCustomizer<IGlobalNavigationApplicationCustomizerProperties> {

  private topPlaceholder: PlaceholderContent | undefined;

  @override
  public onInit(): Promise<void> {
    this.context.placeholderProvider.changedEvent.add(this, this.renderPlaceHolders);
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
