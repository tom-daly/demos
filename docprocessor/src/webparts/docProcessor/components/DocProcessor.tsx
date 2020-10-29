import * as React from "react";
import styles from "./DocProcessor.module.scss";
import { IDocProcessorProps } from "./IDocProcessorProps";
import { IDocProcessorState } from "./IDocProcessorState";
import Dropzone from "react-dropzone";
import { SPComponentLoader } from "@microsoft/sp-loader";
import { MoveOperations, sp } from "@pnp/sp";
import { PrimaryButton } from "office-ui-fabric-react";
import {
  DateTimePicker,
  DateConvention,
} from "@pnp/spfx-controls-react/lib/dateTimePicker";
import TaxonomyWrapper from "./TaxonomyWrapper/TaxonomyWrapper";
import { IPickerTerms } from "@pnp/spfx-controls-react/lib/TaxonomyPicker";
import {
  taxonomy,
  ITermStore,
  ITerm,
} from "@pnp/sp-taxonomy";

export default class DocProcessor extends React.Component<
  IDocProcessorProps,
  IDocProcessorState
> {
  constructor(props) {
    super(props);
    this.state = {
      uploads: [],
      projects: [],
      submittalAction: [],
      gaPhase: [],
      subCategory: null,
      agencies: [],
      documentStatus: [],
      byWhom: [],
      trades: [],
      documentDate: null,
      actionDate: null,
      loading: false,
      loadingScripts: true,
      errors: []
    };
  }

  private getTermString(pickerTerms) {
    let termString = "";
    pickerTerms.forEach((term) => {
      termString += `-1;#${term["name"]}|${term["key"]};#`;
    });
    return termString.slice(0, -2);
  }

  public componentDidMount() {
    this.loadScripts();
  }

  public getSiteCollectionUrl(): string {
    let baseUrl = window.location.protocol + "//" + window.location.host;
    const pathname = window.location.pathname;
    const siteCollectionDetector = "/sites/";
    if (pathname.indexOf(siteCollectionDetector) >= 0) {
      baseUrl += pathname.substring(
        0,
        pathname.indexOf("/", siteCollectionDetector.length)
      );
    }
    return baseUrl;
  }

  private loadScripts() {
    const siteColUrl = this.getSiteCollectionUrl();
    try {
      SPComponentLoader.loadScript(siteColUrl + "/_layouts/15/init.js", {
        globalExportsName: "$_global_init",
      })
        .then(
          (): Promise<{}> => {
            return SPComponentLoader.loadScript(
              siteColUrl + "/_layouts/15/MicrosoftAjax.js",
              {
                globalExportsName: "Sys",
              }
            );
          }
        )
        .then(
          (): Promise<{}> => {
            return SPComponentLoader.loadScript(
              siteColUrl + "/_layouts/15/SP.Runtime.js",
              {
                globalExportsName: "SP",
              }
            );
          }
        )
        .then(
          (): Promise<{}> => {
            return SPComponentLoader.loadScript(
              siteColUrl + "/_layouts/15/SP.js",
              {
                globalExportsName: "SP",
              }
            );
          }
        )
        .then(
          (): Promise<{}> => {
            return SPComponentLoader.loadScript(
              siteColUrl + "/_layouts/15/SP.taxonomy.js",
              {
                globalExportsName: "SP",
              }
            );
          }
        )
        .then((): void => {
          this.setState({ loadingScripts: false });
        })
        .catch((reason: any) => {
          this.setState({
            loadingScripts: false,
            errors: [...this.state.errors, reason],
          });
        });
    } catch (error) {
      this.setState({
        loadingScripts: false,
        errors: [...this.state.errors, error],
      });
    }
  }

  private onDrop = (acceptedFiles) => {
    console.log(acceptedFiles);
    this.setState(
      {
        uploads: acceptedFiles,
      },
      () => console.log(this.state)
    );
  };

  private asyncForEach = async (array, callback) => {
    for (let index = 0; index < array.length; index++) {
      await callback(array[index], index, array);
    }
  };

  private setTaxFieldProperty = (
    context: SP.ClientContext,
    item: SP.ListItem,
    list: SP.List,
    fieldName: string,
    fieldValues: IPickerTerms,
    isSingle: boolean
  ) => {
    let field = list.get_fields().getByInternalNameOrTitle(fieldName);
    let taxField = context.castTo(field, SP.Taxonomy.TaxonomyField) as SP.Taxonomy.TaxonomyField;

    if (isSingle) {
      if (fieldValues && fieldValues.length >= 1) {
        let termValue = new SP.Taxonomy.TaxonomyFieldValue();
        termValue.set_label(fieldValues[0].name);
        termValue.set_termGuid(new SP.Guid(fieldValues[0].key));
        termValue.set_wssId(-1);
        taxField.setFieldValueByValue(item, termValue);
      }
      else {
        taxField.validateSetValue(item, null);
      }
    }
    else {
      if(fieldValues && fieldValues.length >= 1) {
        let termString = this.getTermString(fieldValues);
        console.log(termString);
        let termValueCollection = new SP.Taxonomy.TaxonomyFieldValueCollection(context, termString, taxField);
        taxField.setFieldValueByValueCollection(item, termValueCollection);
      }
      else {
        taxField.validateSetValue(item, null);
      }
    }
  };

  private getItem = async (context: SP.ClientContext, list: SP.List, itemId: number): Promise<SP.ListItem> => {
    return new Promise((resolve, reject) => {
      const query = `<View Scope='Recursive'><Query><Where><Eq><FieldRef Name=\"ID\" /><Value Type=\"Integer\">${itemId}</Value></Eq></Where></Query></View>`;
      let camlQuery = new SP.CamlQuery();
      camlQuery.set_viewXml(query);
      let allItems = list.getItems(camlQuery);
      context.load(allItems, 'Include(Id)');
      context.executeQueryAsync(
        () => {
          console.log("success", allItems);
          resolve(allItems.get_item(0));
        },
        (sender, args) => {
          console.log("fail", args.get_message());
          resolve();
        }
      );
    });
  }

  private updateItemMetaData = async (siteUrl: string, listName: string, itemId: number) => {
    console.log(siteUrl, listName, itemId);

    return new Promise(async (resolve, reject) => {
      let context = new SP.ClientContext(siteUrl);
      let list = context.get_web().get_lists().getByTitle(listName);
      console.log("ctx list", list);
      let item = await this.getItem(context, list, itemId);
      console.log("ctx item", item);

      this.setTaxFieldProperty(context, item, list, "ByWhom", this.state.byWhom, true);
      this.setTaxFieldProperty(context, item, list, "SubCategory", this.state.subCategory, true);
      this.setTaxFieldProperty(context, item, list, "DocumentStatus", this.state.documentStatus, true);
      this.setTaxFieldProperty(context, item, list, "SubmittalAction", this.state.submittalAction, true);
      this.setTaxFieldProperty(context, item, list, "Phase", this.state.gaPhase, true);
      this.setTaxFieldProperty(context, item, list, "Agencies", this.state.agencies, true);
      this.setTaxFieldProperty(context, item, list, "Trades", this.state.trades, false);
      item.set_item("ActionDate", this.state.actionDate);

      item.update();
      context.load(item);

      context.executeQueryAsync(
        () => {
          console.log("success", item.get_id());
          resolve();
        },
        (sender, args) => {
          console.log("fail", args.get_message());
          resolve();
        }
      );
    });


  };

  private processFiles = async () => {
    console.log(this.state);

    this.setState({
      loading: true,
    });

    //TODO: get info from project Taxonomy_aRm/OUPwaps1t+AbQGcHcQ==
    const store: ITermStore = await taxonomy.termStores.getByName("Taxonomy_aRm/OUPwaps1t+AbQGcHcQ==");
    const projectTerm: ITerm = await store.getTermById(this.state.projects[0].key);
    const projectSiteUrl: string = await projectTerm.getDescription(1033);
    console.log("projectTerm", projectTerm);
    console.log("projectSiteUrl", projectSiteUrl);

    //switching up the context for the target site
    sp.setup({
      sp: {
        baseUrl: `${window.location.protocol}//${window.location.hostname}/${projectSiteUrl}`
      }
    });

    await this.asyncForEach(this.state.uploads, async (file) => {
      console.log("file", file);

      //check if file exists, if so skip
      //check if file is checked out, if so skip
      console.log("pathTerm", this.state.subCategory);
      const path = this.state.subCategory[0].path;
      console.log("path", path);
      const pathTemp = path.split(";");
      console.log("pathTemp");
      const targetFolderName = pathTemp[0];
      const targetFolderUrl = targetFolderName.replace("-","");
      console.log("Target Doc Library Name", targetFolderName, targetFolderUrl);

      const documentsFolderDisplayName = "Documents";
      const documentsFolderUrlName = "Shared%20Documents";

      let list = await sp.web.lists.getByTitle(documentsFolderDisplayName).get();
      console.log("list", list);

      let fileUploaded = await sp.web.getFolderByServerRelativeUrl(`${documentsFolderUrlName}/${targetFolderName}`).files.add(file.name, file, true); //using the url/folder name of the library
      console.log("file uploaded", fileUploaded);

      let listItemAllFields = await fileUploaded.file.listItemAllFields.get();
      console.log("list item", listItemAllFields);

      let update = await this.updateItemMetaData(projectSiteUrl, documentsFolderDisplayName, listItemAllFields.Id); // using display list name of the library

      console.log(file.name + " properties updated successfully!");
    });

    console.log("processing files completed");

    this.reset();
  };

  private reset = () => {
    console.log("reseting form");
    this.setState({
      uploads: [],
      submittalAction: [],
      gaPhase: [],
      agencies: [],
      documentStatus: [],
      byWhom: [],
      trades: [],
      subCategory: [],
      actionDate: null,
      loading: false,
    });
  };

  public render(): React.ReactElement<IDocProcessorProps> {
    return (
      <div className={styles.docProcessor}>
        {!this.state.loadingScripts && (
          <div className={styles.row}>
            <div className={styles.left}>
              <Dropzone onDrop={this.onDrop} disabled={this.state.loading}>
                {({ getRootProps, getInputProps }) => (
                  <section>
                    <div {...getRootProps({ className: "dropzone" })}>
                      <input {...getInputProps()} />
                      <p>
                        Drag 'n' drop some files here, or click to select files
                      </p>
                    </div>
                  </section>
                )}
              </Dropzone>
              {this.state.uploads.map((upload) => (
                <div>{upload.name}</div>
              ))}
            </div>

            <div className={styles.right}>
              <TaxonomyWrapper
                allowMultipleSelections={false}
                termsetNameOrID="GA Projects - Active"
                label="Project (required)"
                values={this.state.byWhom}
                context={this.props.context}
                onValueChanged={(pickerTerms) => {
                  this.setState({ projects: pickerTerms });
                }}
                loading={this.state.loading}
              />

              <TaxonomyWrapper
                allowMultipleSelections={false}
                termsetNameOrID="GA-Sub-Folder-Name"
                label="Sub Category (required)"
                context={this.props.context}
                values={this.state.subCategory}
                onValueChanged={(pickerTerms) => {
                  this.setState({
                    subCategory: pickerTerms,
                  });
                }}
                loading={this.state.loading}
              />

              <TaxonomyWrapper
                allowMultipleSelections={false}
                termsetNameOrID="By Whom"
                label="By Whom"
                values={this.state.byWhom}
                context={this.props.context}
                onValueChanged={(pickerTerms) => {
                  this.setState({ byWhom: pickerTerms });
                }}
                loading={this.state.loading}
              />

              {/* <DateTimePicker
                label="Document Date"
                dateConvention={DateConvention.Date}
                value={this.state.documentDate}
                showLabels={false}
                disabled={this.state.loading}
                onChange={(date) => {
                  this.setState({ documentDate: date });
                }}
              /> */}

              <TaxonomyWrapper
                allowMultipleSelections={false}
                termsetNameOrID="Document Status"
                label="Document Status"
                context={this.props.context}
                values={this.state.documentStatus}
                onValueChanged={(pickerTerms) => {
                  this.setState({
                    documentStatus: pickerTerms,
                  });
                }}
                loading={this.state.loading}
              />

              <TaxonomyWrapper
                allowMultipleSelections={false}
                termsetNameOrID="Submittal Action"
                label="Submittal Action"
                context={this.props.context}
                values={this.state.submittalAction}
                onValueChanged={(pickerTerms) => {
                  this.setState({
                    submittalAction: pickerTerms,
                  });
                }}
                loading={this.state.loading}
              />

              <TaxonomyWrapper
                allowMultipleSelections={true}
                termsetNameOrID="Trades"
                label="Trades"
                context={this.props.context}
                values={this.state.trades}
                onValueChanged={(pickerTerms) => {
                  this.setState({
                    trades: pickerTerms,
                  });
                }}
                loading={this.state.loading}
              />

              <TaxonomyWrapper
                allowMultipleSelections={false}
                termsetNameOrID="Agencies"
                label="Agencies"
                context={this.props.context}
                values={this.state.agencies}
                onValueChanged={(pickerTerms) => {
                  this.setState({
                    agencies: pickerTerms,
                  });
                }}
                loading={this.state.loading}
              />

              <TaxonomyWrapper
                allowMultipleSelections={false}
                termsetNameOrID="GA Phase"
                label="Phase"
                context={this.props.context}
                values={this.state.gaPhase}
                onValueChanged={(pickerTerms) => {
                  this.setState({
                    gaPhase: pickerTerms,
                  });
                }}
                loading={this.state.loading}
              />

              <DateTimePicker
                label="Action Date"
                dateConvention={DateConvention.Date}
                value={this.state.actionDate}
                showLabels={false}
                onChange={(date) => {
                  this.setState({ actionDate: date });
                }}
                disabled={this.state.loading}
              />

              <br />
              <PrimaryButton
                text="Process Files"
                onClick={this.processFiles}
                disabled={this.state.loading || this.state.uploads.length <= 0 || !this.state.projects || !this.state.subCategory}
              />
            </div>
          </div>
        )}

        {this.state.errors}
      </div>
    );
  }
}
