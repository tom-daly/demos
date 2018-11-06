import * as React from 'react';
import * as ReactDom from 'react-dom';
import { Version } from '@microsoft/sp-core-library';
import {
  BaseClientSideWebPart,
  IPropertyPaneConfiguration,
  PropertyPaneTextField
} from '@microsoft/sp-webpart-base';

import * as strings from 'HelloWorldJQuery1EWebPartStrings';
import HelloWorldJQuery1E from './components/HelloWorldJQuery1E';
import { IHelloWorldJQuery1EProps } from './components/IHelloWorldJQuery1EProps';

export interface IHelloWorldJQuery1EWebPartProps {
  description: string;
}

export default class HelloWorldJQuery1EWebPart extends BaseClientSideWebPart<IHelloWorldJQuery1EWebPartProps> {

  public render(): void {
    const element: React.ReactElement<IHelloWorldJQuery1EProps > = React.createElement(
      HelloWorldJQuery1E,
      {
        description: this.properties.description
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

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: {
            description: strings.PropertyPaneDescription
          },
          groups: [
            {
              groupName: strings.BasicGroupName,
              groupFields: [
                PropertyPaneTextField('description', {
                  label: strings.DescriptionFieldLabel
                })
              ]
            }
          ]
        }
      ]
    };
  }
}
