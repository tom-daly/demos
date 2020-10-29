import * as React from 'react';
import * as ReactDom from 'react-dom';
import { Version } from '@microsoft/sp-core-library';
import {
  IPropertyPaneConfiguration,
  PropertyPaneTextField
} from '@microsoft/sp-property-pane';
import { BaseClientSideWebPart, WebPartContext } from '@microsoft/sp-webpart-base';

import * as strings from 'DocProcessorWebPartStrings';
import DocProcessor from './components/DocProcessor';
import { IDocProcessorProps } from './components/IDocProcessorProps';
import "@pnp/polyfill-ie11";
import {sp} from '@pnp/sp';

export interface IDocProcessorWebPartProps {
  context: WebPartContext;
}

export default class DocProcessorWebPart extends BaseClientSideWebPart<IDocProcessorWebPartProps> {

  protected onInit(): Promise<void> {
    sp.setup({spfxContext:this.context});
    return super.onInit();
  }

  public render(): void {
    const element: React.ReactElement<IDocProcessorProps> = React.createElement(
      DocProcessor,
      {
        context: this.context
      }
    );

    ReactDom.render(element, this.domElement);
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
  }

  // protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
  //   return {
  //     pages: [
  //       {
  //         header: {
  //           description: strings.PropertyPaneDescription
  //         },
  //         groups: [
  //           {
  //             groupName: strings.BasicGroupName,
  //             groupFields: [
  //               PropertyPaneTextField('description', {
  //                 label: strings.DescriptionFieldLabel
  //               })
  //             ]
  //           }
  //         ]
  //       }
  //     ]
  //   };
  // }
}
